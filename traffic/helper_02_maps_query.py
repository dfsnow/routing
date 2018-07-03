#!/usr/bin/python3

import pandas.io.sql as psql
import pandas as pd
import requests
import psycopg2
import json
import os
from datetime import datetime

# Loading the necessary files
with open("../config.json") as filename:
      jsondata = json.load(filename)

with open('helper_02_sort_sample.sql', 'r') as query_file:
    query = query_file.read()

# Getting db connection
db_name = jsondata["db_settings"]["db_name"]
db_user = jsondata["db_settings"]["db_user"]
connection = psycopg2.connect("dbname={} user={}".format(db_name, db_user))

# Getting api details and vars
base_url = "https://maps.googleapis.com/maps/api/directions/json?"
traffic_model = jsondata["traffic_settings"]["traffic_model"]
api_key = jsondata["traffic_settings"]["google_api_key"]
dep_time = jsondata["traffic_settings"]["departure_datetime"]
dep_time = str(int(datetime.strptime(dep_time, "%Y-%m-%d %H:%M:%S").timestamp()))

# Getting the relevant osm ids
osm_ids = psql.read_sql_query("SELECT DISTINCT osm_id FROM sample", connection)
osm_ids = [str(i) for i in list(osm_ids['osm_id'])]
geoid = os.environ.get('GEOID')


def get_point_from_db(osm_id):
    """ Retrieve origin, destination, etc. of sampled ways """
    built_query = query.format(osm_id, osm_id, osm_id)
    point = psql.read_sql_query(built_query, connection)
    return point


def query_google_api(origin, destination, waypoints, api_key, departure_time=None, traffic_model=None):
    """ Query the Google Directions API for distance and duration """
    if traffic_model and departure_time:
        url = base_url + \
            "origin={}&destination={}&waypoints={}&departure_time={}&traffic_model={}&key={}".format(
            origin, destination, waypoints, departure_time, traffic_model, api_key)
    else:
        url = base_url + \
            "origin={}&destination={}&waypoints={}&key={}".format(
            origin, destination, waypoints, api_key)
    try:
        response = requests.get(url).json()["routes"][0]["legs"]
        distance = sum(response[i]["distance"]["value"] for i in range(0, len(response)))
        duration = sum(response[i]["duration"]["value"] for i in range(0, len(response)))
        return distance, duration
    except:
        raise ValueError('No results for way.')


def query_loop(df):
    """ Loop through rows and append query info to dataframe """
    for idx, row in df.iterrows():
        print(row['osm_id'])
        try:
            distance, duration = query_google_api(
                row["origin"],
                row["destination"],
                row["waypoint"],
                api_key,
                dep_time,
                "pessimistic")
            df.at[idx, "api_distance"] = distance
            df.at[idx, "api_duration"] = duration
            df.at[idx, "api_minutes"] = duration / 60
            df.at[idx, "api_speed"] = (distance * 6.2e-4) / (duration / 60 ** 2)
        except:
            points.drop(idx, inplace=True)
    df.to_csv(geoid + "-speeds.csv")


# Loop to get points from db
points = pd.DataFrame()
for osm_id in osm_ids:
    result = get_point_from_db(osm_id)
    if len(result) == 1:
        points = points.append(result)

# Clean up the resulting dataframe
points = points.reset_index(drop=True)
points["origin"] = points["olat"].map(str) + "," + points["olon"].map(str)
points["destination"] = points["dlat"].map(str) + "," + points["dlon"].map(str)
points["waypoint"] = points["wlat"].map(str) + "," + points["wlon"].map(str)

# Drop unneeded columns and super extreme outliers
points = points.drop(["olat", "olon", "dlat", "dlon", "wlon", "wlat"], axis=1)
points = points[abs(points.agg_cost - points.agg_cost.mean()) <= (10 * points.agg_cost.std())]

query_loop(points)

connection.close()

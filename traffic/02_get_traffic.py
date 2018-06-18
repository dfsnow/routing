#!/usr/bin/python3

import pandas.io.sql as psql
import pandas as pd
import requests
import psycopg2
import json
from multiprocessing import Pool, cpu_count
from datetime import datetime

# Loading the necessary files
with open("../config.json") as filename:
      jsondata = json.load(filename)

with open('point_finder_query.sql', 'r') as query_file:
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
        response = requests.get(url).json()["routes"][0]["legs"]
        distance = sum(response[i]["distance"]["value"] for i in range(0, len(response)))
        duration = sum(response[i]["duration"]["value"] for i in range(0, len(response)))
    else:
        url = base_url + \
            "origin={}&destination={}&waypoints={}&key={}".format(
            origin, destination, waypoints, api_key)
        response = requests.get(url).json()["routes"][0]["legs"]
        distance = sum(response[i]["distance"]["value"] for i in range(0, len(response)))
        duration = sum(response[i]["duration"]["value"] for i in range(0, len(response)))
    return distance, duration


# Multiprocessing pool to run above functions
points = pd.DataFrame()
with Pool(cpu_count()) as pool:
    points = points.append(pool.map(get_point_from_db, osm_ids))

# Clean up the resulting dataframe
points = points.reset_index(drop=True)
points["origin"] = points["olat"].map(str) + "," + points["olon"].map(str)
points["destination"] = points["dlat"].map(str) + "," + points["dlon"].map(str)
points["waypoint"] = points["wlat"].map(str) + "," + points["wlon"].map(str)

# Drop unneeded columns and super extreme outliers
points = points.drop(["olat", "olon", "dlat", "dlon", "wlon", "wlat"], axis=1)
points = points[abs(points.agg_cost - points.agg_cost.mean()) <= (10 * points.agg_cost.std())]

# Iterate through rows and query google api
for idx, row in points.iterrows():
    distance, duration = query_google_api(
        row["origin"],
        row["destination"],
        row["waypoint"],
        api_key,
        dep_time,
        traffic_model)
    points.at[idx, "api_distance"] = distance
    points.at[idx, "api_duration"] = duration
    points.at[idx, "api_minutes"] = duration / 60
    points.at[idx, "api_speed"] = (distance * 6.2e-4) / (duration / 60 ** 2)


points.to_csv("test.csv")
all_diff = (points.api_speed.mean() - points.maxspeed.mean()) / 2
pg = points.groupby("tag_id").agg(["mean", "count"])[["maxspeed", "api_speed"]]
pg["tag_diff"] = (pg.api_speed["mean"] - pg.maxspeed["mean"]) / 2
pg["final_speed"] = pg.maxspeed["mean"] + pg.tag_diff + all_diff

pg.to_csv("agg.csv")



connection.close()

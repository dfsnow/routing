#!/usr/bin/python3

import pandas.io.sql as psql
import pandas as pd
import requests
import psycopg2
import json
import os
from datetime import datetime

### Non-internet AKA local things
# Loading the necessary files
with open("../config.json") as filename:
      jsondata = json.load(filename)

# Getting the GEOID for the queried county
geoid = os.environ.get('GEOID')

# Getting db connection
db_name = jsondata["db_settings"]["db_name"]
db_user = jsondata["db_settings"]["db_user"]
connection = psycopg2.connect("dbname={} user={}".format(db_name, db_user))

# Departure data and time for Google and other queries
dep_time = jsondata["traffic_settings"]["departure_datetime"]
dep_time_timestamp = str(int(datetime.strptime(dep_time, "%Y-%m-%d %H:%M:%S").timestamp()))
dep_time_isoformat = str(datetime.strptime(dep_time, "%Y-%m-%d %H:%M:%S").isoformat())
dep_time_datetime = str(datetime.strptime(dep_time, "%Y-%m-%d %H:%M:%S"))

# Getting the relevant osm ids
points = psql.read_sql_query("SELECT * FROM sample", connection)
points = points.reset_index(drop=True)
points["origin"] = points["olat"].map(str) + "," + points["olon"].map(str)
points["destination"] = points["dlat"].map(str) + "," + points["dlon"].map(str)
points["origin_r"] = points["olon"].map(str) + "," + points["olat"].map(str)
points["destination_r"] = points["dlon"].map(str) + "," + points["dlat"].map(str)
points = points.drop(columns=["olat", "olon", "dlat", "dlon"])

### Internet things and APIs
# Getting Google api details
google_base_url = "https://maps.googleapis.com/maps/api/directions/json?"
google_traffic_model = jsondata["traffic_settings"]["traffic_model"]
google_api_key = "AIzaSyDbbvQxwtdBPMYLG9BYUr35IQXbW-jzEcQ"

# Getting HERE api details
here_base_url = "https://route.api.here.com/routing/7.2/calculateroute.json?"
here_app_id = "KA4xdwceVJyUmpdTUSKE"
here_app_code = "p_cAWFz1puDT_jQuYOVmEQ"
here_traffic_model = "traffic:enabled"

# Bing API settings
bing_base_url = "http://dev.virtualearth.net/REST/V1/Routes/Driving?o=json&"
bing_api_key = "ApwIOOF0qw8xKuNBsH8dZB6Re21ucM_mLgBs5uXy7jfUUHnpFSUd0-gCHAgKLuk1"
bing_traffic_model = "timeWithTraffic"


def query_google_api(origin, destination, api_key, departure_time=None, traffic_model=None):
    """ Query the Google Directions API for distance and duration """
    if traffic_model and departure_time:
        url = google_base_url + \
            "origin={}&destination={}&departure_time={}&traffic_model={}&key={}".format(
            origin, destination, departure_time, traffic_model, api_key)
    else:
        url = google_base_url + \
            "origin={}&destination={}&key={}".format(
            origin, destination, api_key)
    try:
        response = requests.get(url).json()["routes"][0]["legs"]
        distance = sum(response[i]["distance"]["value"] for i in range(0, len(response)))
        duration = sum(response[i]["duration"]["value"] for i in range(0, len(response)))
        return distance, duration
    except:
        raise ValueError('No results for way.')


def query_here_api(origin, destination, app_id, app_code, departure_time=None, traffic_model=None):
    """ Query the HERE routing API """
    if traffic_model and departure_time:
        url = here_base_url + \
            "app_id={}&app_code={}&waypoint0=geo!{}&waypoint1=geo!{}&mode=fastest;car;{}&departure={}".format(
            app_id, app_code, origin, destination, traffic_model, departure_time)
    else:
        url = here_base_url + \
            "app_id={}&app_code={}&waypoint0=geo!{}&waypoint1=geo!{}&mode=fastest;car;".format(
            app_id, app_code, origin, destination)
    try:
        response = requests.get(url).json()["response"]["route"][0]["summary"]
        distance = int(response["distance"])
        duration = int(response["travelTime"])
        return distance, duration
    except:
        raise ValueError('No results for way.')


def query_osrm_api(origin, destination):
    """ Query the OSRM routing API """
    osrm_base_url = "http://router.project-osrm.org/route/v1/car/"
    url = osrm_base_url + "{};{}".format(origin, destination)
    try:
        response = requests.get(url).json()["routes"][0]["legs"]
        distance = sum(response[i]["distance"] for i in range(0, len(response)))
        duration = sum(response[i]["duration"] for i in range(0, len(response)))
        return distance, duration
    except:
        raise ValueError('No results for way.')


def query_bing_api(origin, destination, api_key, departure_time=None, traffic_model=None):
    """ Query the Bing Maps API """

    if traffic_model and departure_time:
        url = bing_base_url + \
            "wp.0={}&wp.1={}&dateTime={}&optimize={}&routeAttributes=routeSummariesOnly&timeType=departure&key={}".format(
            origin, destination, departure_time, traffic_model, api_key)
    else:
        url = bing_base_url + \
           "wp.0={}&wp.1={}&routeAttributes=routeSummariesOnly&key={}".format(
            origin, destination, api_key)
    try:
        response = requests.get(url).json()["resourceSets"][0]["resources"][0]
        distance = response["travelDistance"]
        duration = response["travelDurationTraffic"]
        return distance, duration
    except:
        raise ValueError('No results for way.')


def query_loop(df):
    """ Loop through rows and append query info to dataframe """
    for idx, row in df.iterrows():
        print(row['id'])
        try:
            google_distance, google_duration = query_google_api(
                row["origin"],
                row["destination"],
                google_api_key,
                dep_time_timestamp,
                "pessimistic")
            here_distance, here_duration = query_here_api(
                row["origin"],
                row["destination"],
                here_app_id,
                here_app_code,
                dep_time_isoformat,
                here_traffic_model)
            osrm_distance, osrm_duration = query_osrm_api(
                row["origin_r"],
                row["destination_r"])
            bing_distance, bing_duration = query_bing_api(
                row["origin"],
                row["destination"],
                bing_api_key,
                dep_time_datetime,
                bing_traffic_model)

            df.at[idx, "google_api_distance"] = google_distance
            df.at[idx, "google_api_minutes"] = google_duration / 60

            df.at[idx, "here_api_distance"] = here_distance
            df.at[idx, "here_api_minutes"] = here_duration / 60

            df.at[idx, "osrm_api_distance"] = osrm_distance
            df.at[idx, "osrm_api_minutes"] = osrm_duration / 60

            df.at[idx, "bing_api_distance"] = bing_distance * 1000  # Bing returned km
            df.at[idx, "bing_api_minutes"] = bing_duration / 60

        except:
            points.drop(idx, inplace=True)

    df.drop(columns=["origin", "destination", "origin_r", "destination_r"], inplace=True)
    df.to_csv(geoid + "-speeds.csv", index=False)

query_loop(points)

connection.close()







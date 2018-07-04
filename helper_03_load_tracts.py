#!/usr/bin/python3

import geopandas as gpd
import pandas as pd
import urllib.request
import requests
import zipfile
import json
import sys
import os

# Populating setup variables from the config file
with open("config.json") as filename:
     jsondata = json.load(filename)

api_key = jsondata["geometry_settings"]["census_api_key"]
year = jsondata["geometry_settings"]["tiger_geometry_year"]
states = pd.read_csv('states.csv')
rel_path = "tracts/"

# Downloading and unzipping the tracts for each state
for fip in states['fip']:
    base_url = "https://www2.census.gov/geo/tiger/GENZ" + str(year) + "/"
    base_file = "gz_" + str(year) + "_" + str(fip).zfill(2) + "_140_00_500k"
    zip_file = base_file + ".zip"
    shp_file = base_file + ".shp"

    print(base_url + zip_file)

    if not os.path.isfile(os.path.join(rel_path, zip_file)):
        urllib.request.urlretrieve(base_url + zip_file,
            os.path.join(rel_path, zip_file))

    if not os.path.isfile(os.path.join(rel_path, shp_file)):
        tract_zip = zipfile.ZipFile(os.path.join(rel_path, zip_file))
        tract_zip.extractall(os.path.join(rel_path))
        tract_zip.close()


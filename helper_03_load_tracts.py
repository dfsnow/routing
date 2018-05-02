#!/usr/bin/python3.5

import geopandas as gpd
import pandas as pd
import urllib.request
import requests
import zipfile
import sys
import os

# Census API key
api_key = "5715ad9a4771612cf866aa434f979c3b00ff6eed"

# Setup variables
year = 2015
states = pd.read_csv('states.csv')
rel_path = "tracts/"

# Downloading and unzipping the tracts for each state
for fip in states['fip']:
    base_url = "https://www2.census.gov/geo/tiger/GENZ" + str(year) + "/shp/"
    base_file = "cb_" + str(year) + "_" + str(fip).zfill(2) + "_tract_500k"
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


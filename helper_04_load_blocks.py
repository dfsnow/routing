#!/usr/bin/python3.5

import geopandas as gpd
import pandas as pd
import urllib.request
import zipfile
import os

# Setup variables and parameters
year = 2010
states = pd.read_csv('states.csv')
rel_path = "blocks/"

# Downloading and unzipping the tracts for each state
for fip in states['fip']:
    base_url = "https://www2.census.gov/geo/tiger/TIGER" + str(year) + "BLKPOPHU/"
    base_file = "tabblock" + str(year) + "_" + str(fip).zfill(2) + "_pophu"
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

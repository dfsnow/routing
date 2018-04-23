#!/usr/bin/python3.5

import geopandas as gpd
import pandas as pd
import urllib.request
import zipfile
import os
import fiona
import requests
from fiona.crs import from_epsg
from shapely.geometry import Polygon, mapping

# Various settings and parameters for the script
year = 2015
buffer = 1e5 # meters
rel_path = "counties/"
schema={
  'geometry': 'Polygon',
  'properties': {'geoid': 'int'},
}

# Creating the URL to download the county shapefiles
base_url = 'https://www2.census.gov/geo/tiger/TIGER' + str(year) + '/COUNTY/'
base_file = 'tl_' + str(year) + '_us_county'
zip_file = base_file + '.zip'
shp_file = base_file + '.shp'

print(base_url + zip_file)

# Download if not downloaded, unzip if not unzipped
if not os.path.isfile(os.path.join(rel_path, zip_file)):
    urllib.request.urlretrieve(base_url + zip_file, os.path.join(rel_path, zip_file))

if not os.path.isfile(os.path.join(rel_path, shp_file)):
    tract_zip = zipfile.ZipFile(os.path.join(rel_path, zip_file))
    tract_zip.extractall(os.path.join(rel_path))
    tract_zip.close()

# Convert shapefile CRS to Albers, buffer, then convert the buffered
# counties back to 83. Necessary for clipping with osmium
gdf = gpd.read_file(os.path.join(rel_path, shp_file))
gdf = gdf.to_crs(epsg = 2163)
gdf['geometry'] = gdf.geometry.buffer(buffer)
gdf = gdf.to_crs(epsg = 4326)
gdf.to_file(os.path.join(rel_path, base_file + '_buffered.shp'),
            driver = 'ESRI Shapefile')

# Save each county as a separate GeoJSON to use as a boundary
# file for osmium clipping
for index, row in gdf.iterrows():
    with fiona.open(os.path.join(rel_path, '{}.geojson'.format(row['GEOID'])), 'w',
        crs=from_epsg(4326), driver='GeoJSON', schema=schema) as output:
        output.write({
            'geometry': mapping(row['geometry']),
            'properties': {'geoid': row['GEOID']}
        })

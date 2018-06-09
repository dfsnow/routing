#!/bin/bash

db_name="$(jq -r .db_settings.db_name config.json)"
db_user="$(jq -r .db_settings.db_user config.json)"

# Setup variables for the visualization
geoid="$(jq -r .visualization_settings.origin_geoid config.json)"
framerate="$(jq -r .visualization_settings.mov_framerate config.json)"
mov_length="$(jq -r .visualization_settings.mov_length config.json)"

state="$(echo $geoid | cut -c 1-2)"
county="$(echo $geoid | cut -c 3-5)"
tract="$(echo $geoid | cut -c 6-11)"

# Create a new temporary database for the viz query
psql -d "$db_name" -U "$db_user" << EOD

DROP TABLE IF EXISTS paths;
CREATE TABLE paths (
    id 		        serial PRIMARY KEY,
    origin	        bigint,
    destination     bigint,
    agg_cost	    float8,
    path_seq	    int
);
SELECT AddGeometryColumn('public','paths','the_geom','4326','LINESTRING',2);
VACUUM (FULL, ANALYZE) paths;

EOD

cat helper_01_query.sql \
  | sed "s/\$state/$state/g" \
  | sed "s/\$county/$county/g" \
  | sed "s/\$tract/$tract/g" \
  > "helper_01_query.sql.tmp"

psql -d "$db_name" -U "$db_user" -f helper_01_query.sql.tmp

cd .. && pipenv run viz/helper_01_plot.py $$ cd viz

ffmpeg -framerate "$framerate" -pattern_type glob -i '*.png' -c:v libx264 \
  -pix_fmt yuv420p -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" "$tract".mp4

#ffmpeg -framerate "$framerate" - seq-%05d.png "$tract".webm
#ffmpeg -i "$tract".mp4 "$tract".webm

rm helper_01_query.sql.tmp
#rm *.png

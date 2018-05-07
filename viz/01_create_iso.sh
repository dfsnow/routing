#!/bin/bash

state='17'
county='031'
tract='330100'

framerate='24'

psql -d batch_network -U snow << EOD
DROP TABLE IF EXISTS paths;
CREATE TABLE paths (
  id 		serial PRIMARY KEY,
  origin	bigint,
  destination   bigint,
  agg_cost	float8,
  path_seq	int
);

SELECT AddGeometryColumn('public','paths','the_geom','4326','LINESTRING',2);
VACUUM (FULL, ANALYZE) paths;
EOD

cat helper_01_query.sql \
  | sed "s/\$state/$state/g" \
  | sed "s/\$county/$county/g" \
  | sed "s/\$tract/$tract/g" \
  > "helper_01_query.sql.tmp"

psql -d batch_network -U snow -f helper_01_query.sql.tmp

python3 helper_01_plot.py

ffmpeg -framerate "$framerate" -i seq-%04d.png -c:v libx264 -pix_fmt yuv420p -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" "$tract".mp4

#ffmpeg -framerate "$framerate" - seq-%04d.png "$tract".webm
#ffmpeg -i "$tract".mp4 "$tract".webm

rm helper_01_query.sql.tmp
#rm *.png

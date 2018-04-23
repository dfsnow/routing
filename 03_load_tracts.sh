#!/bin/bash

# Create directory for tracts if it doesn't exist
if [ ! -d "tracts" ]; then
  mkdir tracts
fi

# Download tract files and unzip them
python3.5 helper_03_load_tracts.py

# Prep database for writing
psql -d batch_network -U snow << EOD

  -- Shapefile type: Polygon
  -- Postgis type: MULTIPOLYGON[2]
  SET CLIENT_ENCODING TO UTF8;
  SET STANDARD_CONFORMING_STRINGS TO ON;
  BEGIN;

  DROP TABLE IF EXISTS tracts;
  CREATE TABLE "public"."tracts" (gid serial,
      "statefp" smallint,
      "countyfp" smallint,
      "tractce" int,
      "affgeoid" varchar(20),
      "geoid" bigint,
      "name" varchar(100),
      "lsad" varchar(2),
      "aland" float8,
      "awater" float8);

  SELECT AddGeometryColumn('public','tracts','geom','4326','MULTIPOLYGON',2);
  COMMIT;

EOD


# Load tract shapefiles into database
cd tracts

for x in $(ls cb_2015_*shp | sed "s/.shp//"); do
  shp2pgsql -I -s 4269:4326 -a -W "latin1" $x public.tracts \
    | grep -v "GIST\|ANALYZE" \
    | psql -d batch_network -U snow
done

psql -d batch_network -U snow << EOD

  ALTER TABLE tracts DROP COLUMN gid,
                     DROP COLUMN affgeoid,
                     DROP COLUMN name,
                     DROP COLUMN lsad,
                     DROP COLUMN aland,
                     DROP COLUMN awater;

  ALTER TABLE tracts RENAME COLUMN statefp  TO state;
  ALTER TABLE tracts RENAME COLUMN countyfp TO county;
  ALTER TABLE tracts RENAME COLUMN tractce  TO tract;

  ALTER TABLE tracts ADD PRIMARY KEY (geoid);
  CREATE INDEX sct_idx ON tracts (state, county, tract);

  SELECT AddGeometryColumn('public','tracts','centroid','4326','POINT',2);
  UPDATE tracts SET centroid = ST_Centroid(geom);

  ALTER TABLE tracts ADD COLUMN area float;
  UPDATE tracts SET area = ST_Area(geom);

  CREATE INDEX ON "public"."tracts" USING GIST ("geom");

  ANALYZE "public"."tracts";

EOD

cd ../

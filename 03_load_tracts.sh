#!/bin/bash

db_name="$(jq -r .db_settings.db_name config.json)"
db_user="$(jq -r .db_settings.db_user config.json)"

# Create directory for tracts if it doesn't exist
if [ ! -d "tracts" ]; then
  mkdir tracts
fi

# Download tract files and unzip them
pipenv run python helper_03_load_tracts.py

# Prep database for writing
psql -d "$db_name" -U "$db_user" << EOD

    -- Shapefile type: Polygon
    -- Postgis type: MULTIPOLYGON[2]
    SET CLIENT_ENCODING TO UTF8;
    SET STANDARD_CONFORMING_STRINGS TO ON;
    BEGIN;
    DROP TABLE IF EXISTS "public"."tracts";
    CREATE TABLE "public"."tracts" (
        gid serial,
        "geo_id" varchar(60),
        "state" smallint,
        "county" smallint,
        "tract" int,
        "name" varchar(90),
        "lsad" varchar(7),
        "censusarea" numeric
        );
    SELECT AddGeometryColumn('public','tracts','geom','4326','MULTIPOLYGON',2);
    COMMIT;

EOD


# Load tract shapefiles into database
cd tracts

for x in $(ls gz_2010_*shp | sed "s/.shp//"); do
  shp2pgsql -I -s 4269:4326 -a -W "latin1" $x public.tracts \
    | grep -v "GIST\|ANALYZE" \
    | psql -d "$db_name" -U "$db_user"
done

psql -d "$db_name" -U "$db_user" << EOD

    ALTER TABLE tracts
    DROP COLUMN gid,
    DROP COLUMN name,
    DROP COLUMN lsad,
    DROP COLUMN censusarea;

    ALTER TABLE tracts RENAME COLUMN geo_id  TO geoid;
    ALTER TABLE tracts ALTER COLUMN geoid TYPE bigint USING RIGHT(geoid, 11)::bigint;
    ALTER TABLE tracts ADD PRIMARY KEY (geoid);

    SELECT AddGeometryColumn('public','tracts','centroid','4326','POINT',2);
    UPDATE tracts SET centroid = ST_Centroid(geom);

    CREATE INDEX sct_idx ON tracts (state, county, tract);
    CREATE INDEX ON "public"."tracts" USING GIST ("geom");

EOD

cd ..

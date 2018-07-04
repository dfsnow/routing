#!/bin/bash

db_name="$(jq -r .db_settings.db_name config.json)"
db_user="$(jq -r .db_settings.db_user config.json)"

# Create directory for counties if none exists
if [ ! -d "counties" ]; then
  mkdir counties
fi

# Download the county file, unzip it, and create buffered county
# geojsons for use with osmium. Remove old geojson first
find ./counties -name "*.geojson" -type f -delete
pipenv run python3 helper_02_load_counties.py

# Prep database for writing
psql -d "$db_name" -U "$db_user" << EOD

    -- Shapefile type: Polygon
    -- Postgis type: MULTIPOLYGON[2]
    SET CLIENT_ENCODING TO UTF8;
    SET STANDARD_CONFORMING_STRINGS TO ON;
    BEGIN;
    DROP TABLE IF EXISTS "public"."counties";
    CREATE TABLE "public"."counties" (
        gid serial,
        "statefp10" smallint,
        "countyfp10" smallint,
        "countyns10" varchar(8),
        "geoid10" varchar(5),
        "name10" varchar(100),
        "namelsad10" varchar(100),
        "lsad10" varchar(2),
        "classfp10" varchar(2),
        "mtfcc10" varchar(5),
        "csafp10" varchar(3),
        "cbsafp10" varchar(5),
        "metdivfp10" varchar(5),
        "funcstat10" varchar(1),
        "aland10" float8,
        "awater10" float8,
        "intptlat10" float8,
        "intptlon10" float8
        );
    SELECT AddGeometryColumn('public','counties','geom','4326','MULTIPOLYGON',2);
    SELECT AddGeometryColumn('public','counties','geom_buffer','4326','MULTIPOLYGON',2);
    COMMIT;

EOD


# Load county shapefiles into database
cd counties

shp2pgsql -I -a -s 4269:4326 -W "latin1" tl_2010_us_county10 public.counties \
    | grep -v "GIST\|ANALYZE" \
    | psql -d "$db_name" -U "$db_user"

shp2pgsql -c -s 4326:4326 -g geom_buffer -W \
    "latin1" tl_2010_us_county10_buffered public.counties_temp \
    | psql -d "$db_name" -U "$db_user"

psql -d "$db_name" -U "$db_user" << EOD

    UPDATE counties c
    SET geom_buffer = ct.geom_buffer
    FROM counties_temp ct
    WHERE c.geoid10 = ct.geoid10;

    DROP TABLE counties_temp;

EOD

# Cleanup after writing, dropping unneeded columns
psql -d "$db_name" -U "$db_user" << EOD

    ALTER TABLE counties
    DROP COLUMN gid,
    DROP COLUMN countyns10,
    DROP COLUMN namelsad10,
    DROP COLUMN lsad10,
    DROP COLUMN classfp10,
    DROP COLUMN mtfcc10,
    DROP COLUMN csafp10,
    DROP COLUMN cbsafp10,
    DROP COLUMN metdivfp10,
    DROP COLUMN funcstat10,
    DROP COLUMN aland10,
    DROP COLUMN awater10,
    DROP COLUMN intptlat10,
    DROP COLUMN intptlon10;

    ALTER TABLE counties RENAME COLUMN name10     TO name;
    ALTER TABLE counties RENAME COLUMN statefp10  TO state;
    ALTER TABLE counties RENAME COLUMN countyfp10 TO county;
    ALTER TABLE counties RENAME COLUMN geoid10    TO geoid;
    ALTER TABLE counties ADD PRIMARY KEY (geoid);

    CREATE INDEX ON "public"."counties" USING GIST ("geom");
    CREATE INDEX ON "public"."counties" USING GIST ("geom_buffer");

EOD

cd ..

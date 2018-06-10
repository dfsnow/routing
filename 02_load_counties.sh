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
        "statefp" smallint,
        "countyfp" smallint,
        "countyns" varchar(8),
        "geoid" varchar(5),
        "name" varchar(100),
        "namelsad" varchar(100),
        "lsad" varchar(2),
        "classfp" varchar(2),
        "mtfcc" varchar(5),
        "csafp" varchar(3),
        "cbsafp" varchar(5),
        "metdivfp" varchar(5),
        "funcstat" varchar(1),
        "aland" float8,
        "awater" float8,
        "intptlat" float8,
        "intptlon" float8
        );
    SELECT AddGeometryColumn('public','counties','geom','4326','MULTIPOLYGON',2);
    SELECT AddGeometryColumn('public','counties','geom_buffer','4326','MULTIPOLYGON',2);
    COMMIT;

EOD


# Load county shapefiles into database
cd counties

shp2pgsql -I -a -s 4269:4326 -W "latin1" tl_2015_us_county public.counties \
    | grep -v "GIST\|ANALYZE" \
    | psql -d "$db_name" -U "$db_user"

shp2pgsql -c -s 4326:4326 -g geom_buffer -W \
    "latin1" tl_2015_us_county_buffered public.counties_temp \
    | psql -d "$db_name" -U "$db_user"

psql -d "$db_name" -U "$db_user" << EOD

    UPDATE counties c
    SET geom_buffer = ct.geom_buffer
    FROM counties_temp ct
    WHERE c.geoid = ct.geoid;

    DROP TABLE counties_temp;

EOD

# Cleanup after writing, dropping unneeded columns
psql -d "$db_name" -U "$db_user" << EOD

    ALTER TABLE counties
    DROP COLUMN gid,
    DROP COLUMN countyns,
    DROP COLUMN namelsad,
    DROP COLUMN lsad,
    DROP COLUMN classfp,
    DROP COLUMN mtfcc,
    DROP COLUMN csafp,
    DROP COLUMN cbsafp,
    DROP COLUMN metdivfp,
    DROP COLUMN funcstat,
    DROP COLUMN intptlat,
    DROP COLUMN intptlon;

    ALTER TABLE counties
    RENAME COLUMN statefp  TO state,
    RENAME COLUMN countyfp TO county;
    ALTER TABLE counties ADD PRIMARY KEY (geoid);

    CREATE INDEX ON "public"."counties" USING GIST ("geom");
    CREATE INDEX ON "public"."counties" USING GIST ("geom_buffer");

EOD

cd ..

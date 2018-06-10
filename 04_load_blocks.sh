#!/bin/bash

db_name="$(jq -r .db_settings.db_name config.json)"
db_user="$(jq -r .db_settings.db_user config.json)"

# Create directory for blocks if it doesn't exist
if [ ! -d "blocks" ]; then
  mkdir blocks
fi

# Download block files and unzip them
pipenv run python helper_04_load_blocks.py

# Prep database for writing
psql -d "$db_name" -U "$db_user" << EOD

    -- Shapefile type: Polygon
    -- Postgis type: MULTIPOLYGON[2]
    SET CLIENT_ENCODING TO UTF8;
    SET STANDARD_CONFORMING_STRINGS TO ON;
    BEGIN;
    DROP TABLE IF EXISTS blocks;
    CREATE TABLE "public"."blocks" (
        gid serial,
        "statefp10" smallint,
        "countyfp10" smallint,
        "tractce10" int,
        "blockce" int,
        "blockid10" bigint,
        "partflg" varchar(1),
        "housing10" int,
        "pop10" int,
        "tract_pop" int,
        "tract_id" bigint,
        "block_weight" float8);
    SELECT AddGeometryColumn('public','blocks','geom','4326','MULTIPOLYGON',2);
    COMMIT;

EOD


# Load block shapefiles into database
cd blocks

for x in $(ls tabblock2010_*shp | sed "s/.shp//"); do
  shp2pgsql -I -s 4269:4326 -a -W "latin1" $x public.blocks \
    | grep -v "GIST\|ANALYZE" \
    | psql -d "$db_name" -U "$db_user"
done

psql -d "$db_name" -U "$db_user" << EOD

    ALTER TABLE blocks
    DROP COLUMN gid,
    DROP COLUMN partflg,
    DROP COLUMN housing10;

    ALTER TABLE blocks RENAME COLUMN statefp10  TO state;
    ALTER TABLE blocks RENAME COLUMN countyfp10 TO county;
    ALTER TABLE blocks RENAME COLUMN tractce10  TO tract;
    ALTER TABLE blocks RENAME COLUMN blockce    TO block;
    ALTER TABLE blocks RENAME COLUMN blockid10  TO geoid;
    ALTER TABLE blocks RENAME COLUMN pop10      TO block_pop;

    ALTER TABLE blocks ADD PRIMARY KEY (geoid);
    CREATE INDEX blk_idx ON blocks (state, county, tract, block);

    UPDATE blocks SET tract_id = LEFT(geoid::varchar, -4)::bigint;
    UPDATE blocks b SET tract_pop = t.pop
    FROM (
        SELECT tract_id, sum(block_pop) AS pop
        FROM blocks
        GROUP BY tract_id
    ) t
    WHERE b.tract_id = t.tract_id
    AND b.tract_pop IS DISTINCT FROM t.pop;
    UPDATE blocks SET block_weight = block_pop::numeric/NULLIF(tract_pop::numeric,0);

    SELECT AddGeometryColumn('public','blocks','centroid','4326','POINT',2);
    UPDATE blocks SET centroid = ST_Centroid(geom);
    ALTER TABLE blocks DROP COLUMN geom;

    CREATE INDEX ON "public"."blocks" USING GIST ("centroid");

EOD

cd ..

# Weighting tracts by block centroids
psql -d "$db_name" -U "$db_user" -f helper_04_weight_tracts.sql

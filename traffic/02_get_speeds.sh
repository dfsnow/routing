#!/bin/bash

# Loading config variables
base_dir="$(jq -r .base_dir ../config.json)"
eval "$(jq -r ".db_settings | to_entries | map(\"\(.key)=\(.value |
    tostring)\")|.[]" ../config.json)"
eval "$(jq -r ".routing_settings | to_entries | map(\"\(.key)=\(.value |
    tostring)\")|.[]" ../config.json)"


for GEOID in $(cat urban_sample.csv); do
    x=$base_dir/counties/$GEOID.geojson
    echo "Now processing "$x""

    if [ ! -f "$GEOID"-speeds.csv ]; then

        osmium extract -p "$x" $base_dir/tag_extract.pbf \
            --overwrite \
            -o $base_dir/temp.osm

        # Removing trailing backslash characters from the osm file
        sed -i 's/\\//g' $base_dir/temp.osm

        osm2pgrouting -U "$db_user" \
            -d "$db_name" \
            -c "$osm2pg_mapconfig" \
            --f $base_dir/temp.osm \
            --clean \
            --password "$db_password"

        # Write default maxspeeds. Must be done every loop
        psql -d "$db_name" -U "$db_user" -a -f $base_dir/"$osm_way_config"

        # Deleting isolated ways and nodes
        psql -d "$db_name" -U "$db_user" -a -f $base_dir/helper_05_connected_components.sql

        # Creating a new random sample from the ways
        psql -d "$db_name" -U "$db_user" -a -f 01_create_sample.sql

        # Creating env variables for use in matrix script
        export GEOID="$(basename "$x" | cut -c 1-5)"

        pipenv run python $base_dir/traffic/helper_02_maps_query.py

    fi

done

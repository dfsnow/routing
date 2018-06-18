#!/bin/bash

# Get necessary config vars and locs
s3_path="$(jq -r .docker_settings.s3_path config.json)"
base_dir="$(jq -r .base_dir config.json)"

eval "$(jq -r ".db_settings | to_entries | map(\"\(.key)=\(.value |
     tostring)\")|.[]" config.json)"
eval "$(jq -r ".routing_settings | to_entries | map(\"\(.key)=\(.value |
     tostring)\")|.[]" config.json)"
tags="$(jq -r '.routing_settings.osm_way_tags | join(",")' config.json)"

# Ask about making new tag extract
if [ -f "tag_extract.pbf" ]; then
    while true; do
        read -p "Do you want to make a new tag extract? " yn
            case $yn in
                [Yy]* ) osmium tags-filter "$osm_filename" \
                w/highway="$tags" \
                --overwrite \
                -o tag_extract.pbf; break;;
                [Nn]* ) break;;
            * ) echo "Please answer yes or no.";;
        esac
    done
else
    osmium tags-filter "$osm_filename" \
    w/highway="$tags" \
    --overwrite \
    -o tag_extract.pbf
fi


for state in $(tail -n +2 states.csv | cut -d ',' -f 1); do
    for x in $(find ./counties -name "$(printf %02d "$state")*.geojson" -type f | sort); do

        geoid=$(basename "$x" | cut -c 1-5)
        output_osm="$base_dir"/raw/osm/"$geoid".pbf
        output_loc="$base_dir"/raw/locations/"$geoid".csv
        s3_osm="$s3_path"/osm/"$geoid".pbf
        s3_loc="$s3_path"/locations/"$geoid".csv

        if [ ! -f "$output_osm" ]; then
            echo "Clipping tag extract for $geoid"
            osmium extract -p "$x" tag_extract.pbf \
                --overwrite \
                -o "$output_osm"
        fi

        if [ ! -f "$output_loc" ]; then
            echo "Writing locations for $geoid"
            geom="$(jq -r .features[].geometry "$x")"
            psql -d "$db_name" -U "$db_user" -c "\COPY (
                SELECT geoid, ST_X(centroid) AS X, ST_Y(centroid) AS Y,
                    CASE WHEN geoid::text LIKE '$geoid%'
                    THEN 2 ELSE 1 END AS dir
                FROM tracts
                WHERE ST_Contains(ST_SetSRID(
                ST_GeomFromGeoJSON('$geom'), 4326), centroid))
                TO '$output_loc' DELIMITER ',' CSV;"
        fi

        if [ ! $(s3cmd ls $s3_osm | wc -l) -gt 0 ]; then
            echo "Uploading $geoid.pbf to S3"
            s3cmd put "$output_osm" "$s3_osm"
        fi

        if [ ! $(s3cmd ls $s3_loc | wc -l) -gt 0 ]; then
            echo "Uploading $geoid.csv to S3"
            s3cmd put "$output_loc" "$s3_loc"
        fi

    done
done


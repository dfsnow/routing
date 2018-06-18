#!/bin/bash

## Loading all necessary variables from config file
# Loading config variables
base_dir="$(jq -r .base_dir config.json)"
prompt="$(jq -r .prompt_to_overwrite config.json)"
eval "$(jq -r ".package_versions | to_entries | map(\"\(.key)=\(.value |
    tostring)\")|.[]" config.json)"
eval "$(jq -r ".db_settings | to_entries | map(\"\(.key)=\(.value |
    tostring)\")|.[]" config.json)"
eval "$(jq -r ".routing_settings | to_entries | map(\"\(.key)=\(.value |
    tostring)\")|.[]" config.json)"
tags="$(jq -r '.routing_settings.osm_way_tags | join(",")' config.json)"
notify="$(jq -r .notification_settings.notify config.json)"


## Start of main script
# Downloads the latest North America extract if it doesn't exist
if [ ! -f "$osm_filename" ]; then
    wget https://download.geofabrik.de/north-america-latest.osm.pbf \
        -O "$osm_filename"
fi


# Prompt asking whether or not to clear the previous output
if [ "$prompt" = true ]; then
    while true; do
        read -p "Do you want to clear the previous cost matrix table? " yn
        case $yn in
            [Yy]* ) psql -d "$db_name" \
            -U "$db_user" \
            -f helper_05_create_table.sql; break;;
            [Nn]* ) break;;
        * ) echo "Please answer yes or no.";;
        esac
    done
fi

# Prompt asking whether or not to build a new tag extract, takes awhile
if [ -f "tag_extract.pbf" ]; then
    if [ "$prompt" = true ]; then
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
    fi
else
    osmium tags-filter "$osm_filename" \
	w/highway="$tags" \
	--overwrite \
	-o tag_extract.pbf
fi

# Main loop. It does the following:
# 1. Uses each county geojson to make an osmium extract
# 2. Creates an osm2pgrouting table with the extract
# 3. Adds updated maxspeeds to the configuration table
# 4. Performs KNN match and updates the tracts table
# 5. Creates and writes the cost matrix to a separate table

for x in $(find ./counties -name "*.geojson" -type f | sort); do
	echo "Now processing "$x""

	osmium extract -p "$x" tag_extract.pbf \
		--overwrite \
		-o temp.osm

	# Removing trailing backslash characters from the osm file
	sed -i 's/\\//g' temp.osm

	osm2pgrouting -U "$db_user" \
		-d "$db_name" \
		-c "$osm2pg_mapconfig" \
		--f temp.osm \
		--clean \
		--password "$db_pass"

	# Write default maxspeeds. Must be done every loop
	psql -d "$db_name" -U "$db_user" -a -f "$osm_way_config"

	# Deleting isolated ways and nodes
	psql -d "$db_name" -U "$db_user" -a -f helper_05_connected_components.sql

	# KNN matching for all nodes in pgrouting table
	cat helper_05_knn_match.sql \
		| sed "s/\$knn_start/$knn_start/g" \
	    | sed "s/\$knn_step/$knn_step/g" \
        | sed "s/\$knn_max/$knn_max/g" \
		> "helper_05_knn_match.sql.tmp"

	psql -d "$db_name" -U "$db_user" -a -f helper_05_knn_match.sql.tmp

	# Creating env variables for use in matrix script
    export GEOID="$(basename "$x" | cut -c 1-5)"
	state="$(basename "$x" | cut -c 1-2)"
	county="$(basename "$x" | cut -c 3-5)"

    # Run OTP for transit if the necessary files exist in otp/graphs
    if [ -d otp/graphs/"$GEOID" ]; then

        # Generate a matrix for OTP to use
        psql -d "$db_name" -U "$db_user" -c "\COPY (
            SELECT geoid, ST_Y(centroid) AS Y, ST_X(centroid) AS X
            FROM tracts
            WHERE osm_nn IS NOT NULL
        ) TO 'points.csv' DELIMITER ',' CSV HEADER;"
        sed -i '1s/.*/\U&/' points.csv

        # Symlink the OSM to the necessary folder for OTP
        ln -s "$base_dir"/temp.osm "$base_dir"/otp/graphs/"$GEOID"

        # Build the OTP graph object
        java -jar otp/otp-"$otp_major"-shaded.jar \
            --cache otp/ \
            --basePath otp/ \
            --build otp/graphs/"$GEOID"

        # Process OTP graph
        java -jar otp/jython-standalone-"$jython_major".jar \
            -Dpython.path=otp/otp-"$otp_major"-shaded.jar \
            helper_05_otp.py

        psql -d "$db_name" -U "$db_user" -c \
            "\COPY times (origin, destination, agg_cost, type)
              FROM 'matrix.csv' DELIMITER ',' CSV HEADER;"

    fi

	# Creating the final cost matrix and writing to a results table
	cat helper_05_cost_matrix.sql \
		| sed "s/\$state/$state/g" \
	    | sed "s/\$county/$county/g" \
		> "helper_05_cost_matrix.sql.tmp"

	psql -d "$db_name" -U "$db_user" -a -f helper_05_cost_matrix.sql.tmp

    # Remove all unneeded temp files
	#rm *.sql.tmp points.csv matrix.csv "$base_dir"/otp/graphs/"$GEOID"/temp.osm

	# Keep for testing purposes
	#read -p "Press Enter to continue" </dev/tty

done

# Optional notification script for when batch is finished
if [ "$notify" = true ]; then
	pipenv run python helper_05_notify.py
fi

#rm temp.osm

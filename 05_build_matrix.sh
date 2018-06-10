#!/bin/bash

## Loading all necessary variables from config file
# Loading db config variables
db_name="$(jq -r .db_settings.db_name config.json)"
db_user="$(jq -r .db_settings.db_user config.json)"
db_pass="$(jq -r .db_settings.db_password config.json)"
prompt="$(jq -r .prompt_to_overwrite config.json)"

# Loading routing config variables
file="$(jq .routing_settings.osm_filename config.json)"
tags="$(jq .routing_settings.osm_way_tags | join(",") config.json)"
osm_way_config="$(jq -r .routing_settings.osm_way_config config.json)"
osm2pg_mapconfig="$(jq -r .routing_settings.osm2pg_mapconfig config.json)"
knn_start="$(jq -r .routing_settings.knn_start config.json)"
knn_step="$(jq -r .routing_settings.knn_step config.json)"
knn_max="$(jq -r .routing_settings.knn_max config.json)"

# Loading notification settings
notify="$(jq -r .notification_settings.notify config.json)"


## Start of main script
# Downloads the latest North America extract if it doesn't exist
if [ ! -f "$file" ]; then
    wget https://download.geofabrik.de/north-america-latest.osm.pbf \
        -O "$file"
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
if [ -f "tag_extract.pbf" ] && [ "$prompt" = true ]; then
    while true; do
        read -p "Do you want to make a new tag extract? " yn
        case $yn in
            [Yy]* ) osmium tags-filter "$file" \
		    w/highway="$tags" \
	            --overwrite \
		    -o tag_extract.pbf; break;;
	    [Nn]* ) break;;
	    * ) echo "Please answer yes or no.";;
        esac
    done
else
    osmium tags-filter "$file" \
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
    geoid="$(basename "$x" | cut -c 1-5)"
	state="$(basename "$x" | cut -c 1-2)"
	county="$(basename "$x" | cut -c 3-5)"

	# Creating the final cost matrix and writing to a results table
	cat helper_05_cost_matrix.sql \
		| sed "s/\$state/$state/g" \
	    | sed "s/\$county/$county/g" \
		> "helper_05_cost_matrix.sql.tmp"

	psql -d "$db_name" -U "$db_user" -a -f helper_05_cost_matrix.sql.tmp

	rm *.sql.tmp

	# Keep for testing purposes
	#read -p "Press Enter to continue" </dev/tty

done

# Optional notification script for when batch is finished
if [ "$notify" = true ]; then
	pipenv run python helper_05_notify.py
fi

rm temp.osm

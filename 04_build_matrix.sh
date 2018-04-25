#!/bin/bash

file="north-america-latest.osm.pbf"

tags="motorway,trunk,primary,secondary,tertiary,unclassified,residential,living_street,\
     service,motorway_link,trunk_link,primary_link,secondary_link,tertiary_link"

# Downloads the latest North America extract if it doesn't exist
if [ ! -f "$file" ]; then
    wget https://download.geofabrik.de/north-america-latest.osm.pbf
fi

# Prompt asking whether or not to clear the previous output
while true; do
    read -p "Do you want to clear the previous cost matrix table? " yn
    case $yn in
        [Yy]* ) psql -d batch_network \
		-U snow \
		-f helper_04_create_table.sql; break;;
        [Nn]* ) break;;
	* ) echo "Please answer yes or no.";;
    esac
done

# Prompt asking whether or not to build a new tag extract, takes awhile
if [ -f "tag_extract.pbf" ]; then
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

	osm2pgrouting -U snow \
		-d batch_network \
		-c /usr/local/share/osm2pgrouting/mapconfig.xml \
		--f temp.osm \
		--clean \
		--password Stonefish21

	# Write default maxspeeds. Must be done every loop
	psql -d batch_network -U snow -a -f helper_04_configuration.sql

	# Deleting isolated ways and nodes
	psql -d batch_network -U snow -a -f helper_04_connected_components.sql

	# Creating env variables for use in scripts 
	state="$(basename "$x" | cut -c 1-2)"
	county="$(basename "$x" | cut -c 3-5)"

	# KNN matching for all nodes in pgrouting table
	cat helper_04_knn_match.sql \
		| sed "s/\$state/$state/g" \
		| sed "s/\$county/$county/g" \
		> "helper_04_knn_match.sql.tmp"

	psql -d batch_network -U snow -a -f helper_04_knn_match.sql.tmp

	# Creating the final cost matrix and writing to a results table
	cat helper_04_cost_matrix.sql \
		| sed "s/\$state/$state/g" \
	        | sed "s/\$county/$county/g" \
		> "helper_04_cost_matrix.sql.tmp"

	psql -d batch_network -U snow -a -f helper_04_cost_matrix.sql.tmp
	rm helper_04_cost_matrix.sql.tmp

	# Keep for testing purposes
	#read -p "Press Enter to continue" </dev/tty
done

rm temp.osm

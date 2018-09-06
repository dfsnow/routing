#!/bin/bash

# Loading config variables
base_dir="$(jq -r .base_dir ../config.json)"
eval "$(jq -r ".docker_settings | to_entries | map(\"\(.key)=\(.value |
    tostring)\")|.[]" ../config.json)"
eval "$(jq -r ".db_settings | to_entries | map(\"\(.key)=\(.value |
    tostring)\")|.[]" ../config.json)"


for ur in suburban; do
    for GEOID in $(cat "$ur"/"$ur"_sample.csv); do
        output_csv="$ur"/"$GEOID".csv

        if [ ! -f "$output_csv" ]; then
        s3cmd get "$s3_path"/output/"$GEOID".csv "$output_csv"
        fi

        psql -d "$db_name" -U "$db_user" -c "TRUNCATE TABLE times;"

        psql -d "$db_name" -U "$db_user" -c "\COPY times(origin, destination, agg_cost)
        FROM '"$ur"/"$GEOID".csv' DELIMITER ',' CSV;"

        cat 02_create_sample.sql \
            | sed "s/\$geoid/$GEOID/g" \
            > "02_create_sample.sql.tmp"

        psql -d "$db_name" -U "$db_user" -a -f 02_create_sample.sql.tmp
        rm 02_create_sample.sql.tmp

        export GEOID="$GEOID"
        pipenv run python $base_dir/speeds/03_compare_speeds.py

    done
done


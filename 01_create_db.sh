#!/bin/bash

db_name="$(jq -r .db_settings.db_name config.json)"
db_user="$(jq -r .db_settings.db_user config.json)"

createdb "$db_name" -O "$db_user"

sudo -u postgres psql "$db_name" -c \
  "CREATE EXTENSION postgis; \
   CREATE EXTENSION pgrouting; \
   CREATE EXTENSION postgis_topology;"



#!/bin/bash

db_name="$(jq -r .db_settings.db_name config.json)"
db_user="$(jq -r .db_settings.db_user config.json)"
db_pass="$(jq -r .db_settings.db_password config.json)"

sudo -u postgres psql << EOD
    CREATE USER $db_user PASSWORD '$db_pass';
    GRANT ALL ON SCHEMA public TO $db_user;
    GRANT ALL ON ALL TABLES IN SCHEMA public TO $db_user;
    ALTER USER $db_user CREATEDB;
EOD

createdb "$db_name" -O "$db_user"
sudo -u postgres psql "$db_name" -c \
  "CREATE EXTENSION postgis; \
   CREATE EXTENSION pgrouting; \
   CREATE EXTENSION postgis_topology;"



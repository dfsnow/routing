#!/bin/bash

createdb batch_network -O snow

sudo -u postgres psql batch_network -c \
  "CREATE EXTENSION postgis; CREATE EXTENSION pgrouting; CREATE EXTENSION postgis_topology;"



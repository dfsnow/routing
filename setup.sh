#!/bin/bash

# Install some necessary dependencies
sudo apt install -y wget git ca-certificates

# Get origin directory of the script
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Install jq for parsing config file and set script directory as base directory
sudo apt install -y jq software-properties-common dirmngr g++
tmp="$(tempfile)"
jq -r ".base_dir = \"$script_dir\"" config.json > "$tmp" && mv "$tmp" config.json | unset tmp

# Get software version numbers
postgresql_major="$(jq .package_versions.postgresql_major config.json)"
postgis_major="$(jq .package_versions.postgis_major config.json)"

# Install PostgreSQL, pgrouting, and PostGIS
sudo sh -c 'echo 'deb http://apt.postgresql.org/pub/repos/apt/ stretch-pgdg main' \
    >> /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt update
sudo apt install -y postgresql-$postgresql_major \
    postgresql-$postgresql_major-postgis-$postgis_major \
    postgresql-$postgresql_major-postgis-scripts \
    postgresql-$postgresql_major-pgrouting \
    postgis

# Install osmconvert and osmctools
sudo apt install -y osmctools

# Install osmium and osm2pgrouting dependencies
sudo apt install -y libosmium2-dev libprotozero-dev libutfcpp-dev cmake cmake-curses-gui libpqxx-dev\
    rapidjson-dev libboost-program-options-dev libboost-dev libbz2-dev zlib1g-dev libexpat1-dev

# Install osmium-tool from source
mkdir work
cd work
git clone https://github.com/mapbox/protozero
git clone https://github.com/osmcode/libosmium
git clone https://github.com/osmcode/osmium-tool

cd osmium-tool
mkdir build
sudo sh -c 'cd build && cmake .. && make && make install'
cd ../..

# Install osm2pgrouting from source
git clone https://github.com/pgRouting/osm2pgrouting.git
sudo sh -c 'cd osm2pgrouting && \
    cmake -H. -Bbuild && \
    cd build/ && make && make install'

cd $script_dir
rm -rf work

# Install python3.7 and dependencies
sudo add-apt-repository -y ppa:deadsnakes/ppa
sudo apt-get update
sudo apt install -y python3.7 python3-pip gdal-bin libgdal-dev python3-numpy python3-gdal python3.7-dev
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.7 1
sudo update-alternatives --install /usr/bin/python python /usr/bin/python3.7 2

# Install pipenv and the necessary modules
pip install --user pipenv
pippath="$(python3 -m site --user-base)"
echo PATH="\$PATH:$pippath/bin" >> ~/.profile
source ~/.profile
pipenv install

# Install Java Runtime Environment for OTP
sudo apt install -y default-jre

# Download standalone jars for OTP and Jython
mkdir otp
cd otp
wget https://repo1.maven.org/maven2/org/opentripplanner/otp/1.2.0/otp-1.2.0-shaded.jar
wget http://search.maven.org/remotecontent?filepath=org/python/jython-standalone/2.7.0/jython-standalone-2.7.0.jar \
    -O jython-standalone-2.7.0.jar
cd $script_dir

db_pass="$(jq -r .db_settings.db_password config.json)"
db_user="$(jq -r .db_settings.db_user config.json)"

sudo -u postgres psql << EOD

    CREATE USER $db_user PASSWORD '$db_pass';
    GRANT ALL ON SCHEMA public TO $db_user;
    GRANT ALL ON ALL TABLES IN SCHEMA public TO $db_user;

EOD


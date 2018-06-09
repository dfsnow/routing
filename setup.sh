#!/bin/bash

# Install some necessary dependencies
sudo apt-get install wget ca-certificates

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
sudo apt install -y libosmium2-dev libprotozero-dev libutfcpp-dev cmake libpqxx-dev\
    rapidjson-dev libboost-program-options-dev libboost-dev libbz2-dev zlib1g-dev libexpat1-dev

# Install osmium-tool from source
mkdir work
cd work
git clone https://github.com/mapbox/protozero
git clone https://github.com/osmcode/libosmium
git clone https://github.com/osmcode/osmium-tool

cd osmium-tool
mkdir build
cd build && cmake .. && ccmake . && make
cd ../..

# Install osm2pgrouting from source
git clone https://github.com/pgRouting/osm2pgrouting.git
cd osm2pgrouting && \
    cmake -H. -Bbuild && \
    cd build/ && make && make install

cd $script_dir
rm -rf work

# Install pipenv and the necessary modules
sudo add-apt-repository ppa:deadsnakes/ppa
sudo apt-get update
sudo apt install -y python3.7 python3-pip gdal-bin libgdal-dev python3-numpy python3-gdal
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.7 1
sudo update-alternatives --install /usr/bin/python python /usr/bin/python3.7 2

pip install --user pipenv
pippath="$(python3 -m site --user-base)"
echo PATH="\$PATH:$pippath/bin" >> ~/.profile
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


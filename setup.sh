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
eval "$(jq -r ".package_versions | to_entries | map(\"\(.key)=\(.value | tostring)\")|.[]" config.json)"

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
sudo rm -rf work
sudo rm -rf osm2pgrouting

# Install python3.7 and dependencies
sudo add-apt-repository -y ppa:deadsnakes/ppa
sudo apt-get update
sudo apt install -y python$python_major python3-pip gdal-bin libgdal-dev \
    python3-numpy python3-gdal python$python_major-dev libfreetype6-dev
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python$python_major 1

# Install pipenv and the necessary modules
pip3 install --upgrade pip==9.0.3
pip3 install --user pipenv

PYTHON_BIN_PATH="$(python3 -m site --user-base)/bin"
echo "PATH="\$PATH:$PYTHON_BIN_PATH"" >> ~/.profile
source ~/.profile
pipenv install

# Install Java Runtime Environment for OTP
sudo apt install -y openjdk-8-jre

# Download standalone jars for OTP and Jython
mkdir otp
cd otp
wget https://repo1.maven.org/maven2/org/opentripplanner/otp/$otp_major/otp-$otp_major-shaded.jar
wget "http://search.maven.org/remotecontent?filepath=org/python/jython-standalone/$jython_major/jython-standalone-$jython_major.jar" \
    -O jython-standalone-2.7.0.jar
cd $script_dir

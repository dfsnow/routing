## O-D Matrix Pipeline Prototype

This repository represents a collection of prototype scripts and files used to calculate origin-destination (OD) matrices for use in access models, such as [E2SFCA](https://www.ncbi.nlm.nih.gov/pubmed/19576837), [3SFCA](https://www.tandfonline.com/doi/abs/10.1080/13658816.2011.624987), or [RAAM](https://github.com/JamesSaxon/raam). 

These scripts are intended to run locally on a linux machine running Postgres 10, PostGIS >= 2.4.2, and pgrouting (see misc/setup.sh for all dependencies). For a more finalized version of this pipeline, see the Dockerized version [here](https://github.com/JamesSaxon/routing-container). 

## Dockerized OpenTripPlanner 

This repository also contains the scripts needed to create OD matrices using a Dockerized version of OpenTripPlanner (OTP). The resulting containers can be run on AWS ECS, allowing one to create OD matrices for many cities simultaneously.

To use this functionality, you must first create an S3 bucket with the following structure and files (replace $GEOID with the 5-digit county FIPS code of your county of interest):

```
s3/
  locations/
    $GEOID.csv
    $GEOID.csv
  osm/
    $GEOID.pbf
    $GEOID.pbf
  graphs/
    $GEOID/
      gtfs-feed-for-your-city.zip
      second-gtfs-feed-for-your-city.zip
```

Where each `$GEOID.csv` contains the following columns: the first column is the geoid of each centroid or point, the next two are the lat and lon, and the last is an indicator of whether or not each point is a destination only (1) or an origin and a destination (2). For example, the file `01013.csv` might contain:

```
1010320300,-86.4594698096637,32.4747385375729,2
1001020100,-86.4867374615877,32.4759643901779,1
1001020200,-86.4727830984391,32.4717631266152,1
1053970700,-87.4745632470657,31.0148818057812,1
1101002800,-86.2529877047407,32.3355399627758,1
1101002900,-86.2477755508665,32.3168832008465,1
1101000500,-86.2824080255492,32.3812090783806,1
1101005609,-86.194891663247,32.3209259547646,1
1101006100,-86.382352046675,32.3144919464401,1
1047957000,-87.1690502591114,32.2022064590135,1
```

Each `$GEOID.pbf` should be a clipped version of the OSM street network representing the relevant county and a 100 km buffer around it. All of these input files can be created using the included scripts, specifically the [create raw input script](https://github.com/dfsnow/routing/blob/master/06_create_raw_inputs.sh).

Finally, place the GTFS feed(s) relevant to your county in a folder named with the 5-digit FIPS code. Once all of these inputs are in place, you can create a Docker container on AWS using the included Docker scripts, then submit jobs to ECS using something like:

```bash
for x in $list_of_county_geoids; do
    aws batch submit-job \
        --job-name otp-$x \
        --job-queue routing-queue-large \
        --job-definition arn:aws:batch:us-east-1:808035620362:job-definition/otp-routing:3 \
        --container-overrides '{"environment" : [{"name" : "GEOID", "value" : "'${x}'"}]}'
done
```

The input files will be downloaded from S3, the container will perform its work, and the output CSV matrix will be put in a folder on S3 named `output`, with each county file named after its FIPS code and appended with `-otp`.

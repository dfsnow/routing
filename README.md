## O-D Matrix Pipeline Prototype

This repository represents a collection of prototype scripts and files used to calculate origin-destination (OD) matrices for use in access models, such as [E2SFCA](https://www.ncbi.nlm.nih.gov/pubmed/19576837), [3SFCA](https://www.tandfonline.com/doi/abs/10.1080/13658816.2011.624987), or [RAAM](https://github.com/JamesSaxon/raam). 

These scripts are intended to run locally on a linux machine running Postgres 10, PostGIS >= 2.4.2, and pgrouting (see misc/setup.sh for all dependencies). For a more finalized version of this pipeline, see the Dockerized version [here](https://github.com/JamesSaxon/routing-container). 

## Dockerized OpenTripPlanner 

This repository also contains the scripts needed for creating OpenTripPlanner (OTP) Docker containers (see ./docker). These containers can be run simultaneously on AWS ECS, allowing one to create OD matrices for all available cities.

#!/bin/bash

for x in $(cat ./counties.csv); do
    aws batch submit-job \
        --job-name otp-$x \
        --job-queue routing-queue \
        --job-definition arn:aws:batch:us-east-1:808035620362:job-definition/otp-routing:2 \
        --container-overrides '{"environment" : [{"name" : "GEOID", "value" : "'${x}'"}]}'
done


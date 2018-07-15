#!/bin/bash

for x in $(ls ./graphs/); do
    aws batch submit-job \
        --job-name otp-$x \
        --job-queue routing-queue-large \
        --job-definition arn:aws:batch:us-east-1:808035620362:job-definition/otp-routing:3 \
        --container-overrides '{"environment" : [{"name" : "GEOID", "value" : "'${x}'"}]}'
done


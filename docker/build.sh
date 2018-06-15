#!/bin/bash

# Import AWS credentials
eval "$(jq -r ".docker_settings | to_entries | map(\"\(.key)=\(.value | tostring)\")|.[]" ~/routing/config.json)"

# Create temp build file with credentials
echo $aws_default_region
cat Dockerfile \
    | sed "s@\$aws_default_region@"$aws_default_region"@g" \
    | sed "s@\$aws_access_key@"$aws_access_key"@g" \
    | sed "s@\$aws_secret_access_key@"$aws_secret_access_key"@g" \
    > DockerfileTemp

# Build container
docker build --no-cache -f DockerfileTemp -t otp .

rm DockerfileTemp

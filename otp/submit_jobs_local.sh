#!/bin/bash

for x in 53033; do

    docker run -it --rm -e GEOID=$x -e USE_BLOCKS=true otp

done

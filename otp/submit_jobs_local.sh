
for x in $(cat missing_final.csv); do
    docker run -it --rm -e GEOID=$x -e USE_BLOCKS=false otp
done

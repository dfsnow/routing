#!/bin/bash

# Make dir for importing OTP graphs from S3
mkdir /otp/graphs/$GEOID

# Download graphs and pbf from S3
s3cmd get --recursive s3://jsaxon-routing/graphs/$GEOID/ /otp/graphs/$GEOID/
s3cmd get s3://jsaxon-routing/osm/$GEOID.pbf /otp/graphs/$GEOID/$GEOID.pbf

# Create the OTP graph object
java -jar /otp/otp-$OTP_VERSION-shaded.jar \
    --cache /otp/ \
    --basePath /otp/ \
    --build /otp/graphs/$GEOID

# Get the locations within the boundary, then clean
s3cmd get s3://jsaxon-routing/locations/$GEOID.csv /otp/$GEOID.csv
echo "GEOID,Y,X" > /otp/$GEOID-dest.csv
awk -F, '{ print $1,$3,$2 }' OFS=, /otp/$GEOID.csv >> /otp/$GEOID-dest.csv

# Split the input file into defined chunks
tail -n +2 /otp/$GEOID-dest.csv > /otp/$GEOID-temp.csv
rows=$(cat /otp/$GEOID-temp.csv | wc -l)
chunk_size=$(expr $rows / $STEPS)
split -l $chunk_size -d /otp/$GEOID-temp.csv /otp/x
echo "GEOID,Y,X" > /otp/$GEOID-orig.csv
cat /otp/x$STEP >> /otp/$GEOID-orig.csv

# Create the OTP matrix
java -jar /otp/jython-standalone-$JYTHON_VERSION.jar \
    -Dpython.path=/otp/otp-$OTP_VERSION-shaded.jar \
    /otp/create_otp_matrix.py

# Save the matrix back to S3
s3cmd put /otp/$GEOID-output.csv s3://jsaxon-routing/output/$GEOID-$STEP-otp.csv

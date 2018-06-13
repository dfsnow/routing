#!/usr/bin/jython
from org.opentripplanner.scripting.api import OtpsEntryPoint
from datetime import datetime
import os
import time
import json

# Importing the current county and config vars
with open("config.json") as filename:
    jsondata = json.load(filename)

maxtt = jsondata["otp_settings"]["maximum_travel_time"]
modes = ','.join(jsondata["otp_settings"]["transport_modes"])
dep_date = datetime.strptime(
    jsondata["otp_settings"]["departure_date"],
    "%Y-%m-%d")
dep_time = datetime.strptime(
    jsondata["otp_settings"]["departure_time"],
    "%H:%M:%S")
geoid = os.environ.get('GEOID')

# Instantiate an OtpsEntryPoint
otp = OtpsEntryPoint.fromArgs(['--graphs', 'otp/graphs', '--router', geoid])

# Start timing the code
start_time = time.time()

# Get the default router
router = otp.getRouter(geoid)

# Create a default request for a given departure time
req = otp.createRequest()
req.setDateTime(
    dep_date.year,
    dep_date.month,
    dep_date.day,
    dep_time.hour,
    dep_time.minute,
    dep_time.second
)                                       # set departure time
req.setMaxTimeSec(maxtt)                # set a limit to maximum travel time
req.setModes(modes)                     # define transport mode
# req.maxWalkDistance = 3000            # set the maximum distance
# req.walkSpeed = walkSpeed             # set average walking speed
# req.bikeSpeed = bikeSpeed             # set average cycling speed

# CSV containing the columns GEOID, X and Y.
points = otp.loadCSVPopulation('points.csv', 'Y', 'X')
dests = otp.loadCSVPopulation('points.csv', 'Y', 'X')


# Create a CSV output
csv = otp.createCSVOutput()
csv.setHeader(['origin', 'destination', 'agg_cost', 'type'])

# Start Loop
for origin in points:
    print "Processing origin: ", origin
    req.setOrigin(origin)
    spt = router.plan(req)
    if spt is None: continue

    # Evaluate the SPT for all points
    result = spt.eval(dests)

    # Add a new row of result in the CSV output
    for r in result:
        csv.addRow([
            origin.getStringData('GEOID'),
            r.getIndividual().getStringData('GEOID'),
            round(r.getTime() / 60, 2),  # time in minutes
            2
        ])

# Save the result
csv.save('matrix.csv')

# Stop timing the code
print("Elapsed time was %g seconds" % (time.time() - start_time))

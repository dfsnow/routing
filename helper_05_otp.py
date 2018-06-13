#!/usr/bin/jython
from org.opentripplanner.scripting.api import OtpsEntryPoint
import os
import time

# Importing the current county
geoid = os.environ.get('GEOID')

# Instantiate an OtpsEntryPoint
otp = OtpsEntryPoint.fromArgs(['--graphs', 'otp/graphs', '--router', geoid])

# Start timing the code
start_time = time.time()

# Get the default router
router = otp.getRouter(geoid)

# Create a default request for a given departure time
req = otp.createRequest()
req.setDateTime(2018, 6, 15, 12, 00, 00)  # set departure time
req.setMaxTimeSec(7200)                   # set a limit to maximum travel time
req.setModes('WALK,BUS,RAIL')             # define transport mode
# req.maxWalkDistance = 3000              # set the maximum distance
# req.walkSpeed = walkSpeed               # set average walking speed
# req.bikeSpeed = bikeSpeed               # set average cycling speed

# CSV containing the columns GEOID, X and Y.
points = otp.loadCSVPopulation('points.csv', 'Y', 'X')
dests = otp.loadCSVPopulation('points.csv', 'Y', 'X')


# Create a CSV output
csv = otp.createCSVOutput()
csv.setHeader(['origin', 'destination', 'agg_cost'])

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
            r.getTime(),
            2
        ])

# Save the result
csv.save('matrix.csv')

# Stop timing the code
print("Elapsed time was %g seconds" % (time.time() - start_time))

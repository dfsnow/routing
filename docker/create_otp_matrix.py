#!/usr/bin/jython
from org.opentripplanner.scripting.api import OtpsEntryPoint
import datetime
import time
import os

# Importing the current county and config vars
geoid = os.environ.get('GEOID')
input_file = '/otp/' + str(geoid) + '-dest.csv'
step_file = '/otp/' + str(geoid) + '-orig.csv'
output_file = '/otp/' + str(geoid) + '-output.csv'

# Getting the datetime for the nearest Monday
today = datetime.datetime.now()
get_day = lambda date, day: date + datetime.timedelta(days=(day-date.weekday() + 7) % 7)
d = get_day(today, 0)

# Instantiate an OtpsEntryPoint
otp = OtpsEntryPoint.fromArgs(['--graphs', '/otp/graphs/', '--router', geoid])

# Start timing the code
start_time = time.time()

# Get the default router
router = otp.getRouter(geoid)

# Create a default request for a given departure time
req = otp.createRequest()
req.setDateTime(d.year, d.month, d.day, 12, 00, 00)
req.setMaxTimeSec(7200)                 # set a limit to maximum travel time
req.setModes('WALK,TRANSIT')            # define transport mode
req.maxWalkDistance = 5000            # set the maximum distance

# CSV containing the columns GEOID, X and Y.
step = otp.loadCSVPopulation(step_file, 'Y', 'X')
dests = otp.loadCSVPopulation(input_file, 'Y', 'X')

# Create a CSV output
csv = otp.createCSVOutput()
csv.setHeader(['origin', 'destination', 'agg_cost'])

# Start Loop
for origin in step:
    print "Processing origin: ", origin
    req.setOrigin(origin)
    spt = router.plan(req)
    if spt is None: continue

    # Evaluate the SPT for all points
    result = spt.eval(dests)

    # Add a new row of result in the CSV output
    for r in result:
        csv.addRow([
            int(origin.getFloatData('GEOID')),
            int(r.getIndividual().getFloatData('GEOID')),
            round(r.getTime() / 60.0, 2)  # time in minutes
        ])

# Save the result
csv.save(output_file)

# Stop timing the code
print("Elapsed time was %g seconds" % (time.time() - start_time))

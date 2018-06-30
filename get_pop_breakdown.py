#!/usr/bin/python3

import pandas as pd
import requests

year = 2016
fips = pd.read_csv('states.csv')['fip']


usa = pd.DataFrame()
for state in fips:
    url = "https://api.census.gov/data/" + \
            str(year) + \
            "/acs/acs5?get=B01001_001E,B08201_008E,B08201_014E,B08201_020E,B08201_026E&for=tract:*&in=state:" + \
            str(state).zfill(2)
    j = requests.get(url).json()
    df = pd.DataFrame(j[1:], columns = j[0])
    df.columns = ["pop", "h1", "h2", "h3", "h4", "state", "county", "tract"]
    df["geoid"] = df["state"] + df["county"] + df["tract"]
    df = df.astype(int)
    df["no_car"] = df["h1"] + (df["h2"] * 2) + (df["h3"] * 3) + (df["h4"] * 4)
    df = df[["geoid", "pop", "no_car"]]
    usa = usa.append(df)

usa.to_csv("us_car_pop.csv")




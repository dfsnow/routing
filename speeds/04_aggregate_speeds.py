import pandas as pd
import statistics as stats
import glob

files = glob.glob('*-speeds.csv')
df = pd.concat((pd.read_csv(f) for f in files))
df['city'] = df['ogeoid'].astype(str).str.pad(11, fillchar='0').str.slice(0, 5)
df = df.mean()

df.to_csv("avg_speeds.csv")


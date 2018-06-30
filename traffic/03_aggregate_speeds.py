
import pandas as pd
import statistics as stats
import glob

files = glob.glob('*-speeds.csv')
df = pd.concat((pd.read_csv(f) for f in files))

df['diff'] = abs(df['length'] - df['api_distance'])
df = df[df['diff'] <= 100]
df = df[["tag_id", "maxspeed", "api_speed"]]

df = df.groupby('tag_id').mean()

tags = pd.read_csv('tags.csv')
df = tags.merge(df, on='tag_id').sort_values('tag_id')

df.to_csv("avg_speeds.csv", index=False)

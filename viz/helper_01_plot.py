#!/usr/bin/python3

import matplotlib
matplotlib.use('Agg')

import matplotlib.pyplot as plt
import psycopg2 as pg
import pandas as pd
import geopandas as gpd
from fiona.crs import from_epsg
from multiprocessing import Pool, cpu_count

# Setup variables
pw = pd.read_csv('../secrets.csv')['password'][0]

state = 17
county = 31
tract = 330100

figsize = (7, 7)
dpi = 200
xlim = [-88.382263, -87.390747]
ylim = [41.448903, 42.128784]
vmin = 10
vmax = 60

# PostGIS connection
connection = pg.connect("""
    dbname='batch_network'
    user='snow'
    host='lab.dfsnow.me'
    password={}
    """.format(pw))

# Query to get all roads in the area
all_roads_query="SELECT the_geom FROM ways"
all_roads_gdf = gpd.GeoDataFrame.from_postgis(
    all_roads_query,
    connection,
    geom_col='the_geom',
    crs = from_epsg(4326))

# Data query for shortest paths, see query.sql
paths_query="SELECT * FROM paths"
paths_gdf = gpd.GeoDataFrame.from_postgis(
    paths_query,
    connection,
    geom_col='the_geom',
    crs = from_epsg(4326))

# Getting tract data to append to plot
tracts_query="""
SELECT t.origin, t.destination, t.agg_cost, tr.geoid, tr.geom
FROM times t
LEFT JOIN tracts tr
ON t.destination = tr.geoid
WHERE t.origin = {}
""".format(str(state) + str(county).zfill(3) + str(tract).zfill(6))
tracts_gdf = gpd.GeoDataFrame.from_postgis(
    tracts_query,
    connection,
    geom_col='geom',
    crs = from_epsg(4326))

# Plot settings, turning off legends, padding. Creating plot bounding box
fig, ax = plt.subplots(1, 1, figsize = figzise))
ax2 = fig.add_axes([0,0,1,1])
ax2.patch.set_alpha(0)
ax2.set_aspect('equal')
ax2.xaxis.set_major_locator(plt.NullLocator())
ax2.yaxis.set_major_locator(plt.NullLocator())
ax2.set_axis_off()
ax2.set_axis_on()
for a in ["bottom", "top", "right", "left"]:
    ax2.spines[a].set_linewidth(0)
ax2.set_xlim(xlim[0], xlim[1])
ax2.set_ylim(ylim[0], ylim[1])

# Plot adjustments
plt.subplots_adjust(top=1, bottom=0, right=1, left=0, hspace=0, wspace=0)
plt.axis([xlim[0], xlim[1], ylim[0], ylim[1]])
plt.margins(0,0)

# Static background ax of all roads within bbox
all_roads_gdf.plot(
    ax=ax2,
    color='black',
    alpha=0.25,
    linewidth=0.1,
    figsize = figsize)

# Colorbar creation and axes
cax = fig.add_axes([0.92, 0.6, 0.02, 0.2])
norm = matplotlib.colors.Normalize(vmin=vmin, vmax=vmax)
cb = matplotlib.colorbar.ColorbarBase(
        cax, cmap="BuPu_r", norm=norm)
#cb.set_label("Minutes From Origin", labelpad=-38, size=9)
cb.ax.tick_params(labelsize=8) 

# Largest sequences and destination of each path
paths_ends = paths_gdf.groupby('destination')['path_seq'].max().reset_index()
paths_ends.columns = ['destination', 'end_seq']
paths_dict = {}

# Creating and saving each subplot of paths, tracts, and base roads

def create_frames(i):
    paths_dict[i] = paths_ends[paths_ends['end_seq'] <= i]['destination'].tolist()
    tracts_ends = tracts_gdf[tracts_gdf['destination'].isin(
        paths_dict[i])][['agg_cost', 'geoid', 'geom']]

    ax.set_aspect('equal')
    ax.xaxis.set_major_locator(plt.NullLocator())
    ax.yaxis.set_major_locator(plt.NullLocator())
    ax.set_axis_off()
    ax.set_axis_on()
    for a in ["bottom", "top", "right", "left"]:
        ax.spines[a].set_linewidth(0)
    ax.set_xlim(xlim[0], xlim[1])
    ax.set_ylim(ylim[0], ylim[1])

    if not tracts_ends.empty:
        tracts_ends.plot(
            ax=ax,
            column="agg_cost",
            cmap="BuPu_r",
            alpha=0.5,
            vmin=vmin,
            vmax=vmax,
            legend=False,
            figsize = figsize)

    paths_gdf[paths_gdf['path_seq'] <= i].plot(
        ax=ax,
        color='midnightblue',
        alpha=0.9,
        linewidth=0.3,
        figsize = figsize)

    fig.savefig(
            'seq-{}.png'.format(str(i).zfill(4)),
            bbox_inches='tight',
            pad_inches=0,
            dpi=dpi)
    ax.clear()

pool = Pool(cpu_count())
pool.map(create_frames, range(1, max(paths_ends['end_seq']) + 1))

connection.close()

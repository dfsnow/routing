#!/usr/bin/python3

import os
import json
import matplotlib
matplotlib.use('Agg')

import matplotlib.pyplot as plt
import psycopg2 as pg
import pandas as pd
import geopandas as gpd
from fiona.crs import from_epsg
from multiprocessing import Pool, cpu_count


# Populating setup variables from the config file
with open("../config.json") as filename:
    jsondata = json.load(filename)

db = jsondata["db_settings"]
viz = jsondata["visualization_settings"]

framerate = viz["mov_framerate"]
mov_length = viz["mov_length"]
figsize = tuple(viz["mov_size"])
dpi = viz["mov_dpi"]

xlim = viz["mov_xlim"]
ylim = viz["mov_ylim"]

# PostGIS connection
connection = pg.connect("""
    dbname={0}
    user={1}
    host={2}
    password={3}
    """.format(
        db["db_name"],
        db["db_user"],
        db["db_host"],
        db["db_password"]))

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
""".format(viz["origin_geoid"])

tracts_gdf = gpd.GeoDataFrame.from_postgis(
    tracts_query,
    connection,
    geom_col='geom',
    crs = from_epsg(4326))

# Plot settings, turning off legends, padding. Creating plot bounding box
fig, ax = plt.subplots(1, 1, figsize = figsize)
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

# Setting the max and min interval for frames and colorbar
amin = min(paths_gdf['agg_cost']) # for frames
amax = max(paths_gdf['agg_cost'])
vmin = round(amin, -1) + 10 # for colorbar
vmax = round(amax, -1) - 80

# Colorbar and axes creation
cax = fig.add_axes([0.92, 0.6, 0.02, 0.2])
norm = matplotlib.colors.Normalize(vmin=vmin, vmax=vmax)
cb = matplotlib.colorbar.ColorbarBase(
        cax, cmap="BuPu_r", norm=norm)
cb.ax.tick_params(labelsize=8)

# Get max agg_cost and destination of each path
paths_ends = paths_gdf.groupby('destination')['agg_cost'].max().reset_index()
paths_ends.columns = ['destination', 'end_cost']
paths_dict = {}

# Creating and saving each subplot of paths, tracts, and base roads
def create_frames(i):
    paths_dict[i] = paths_ends[
        paths_ends['end_cost'] <= (i / 60)]['destination'].tolist()
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
            figsize=figsize)

    paths_gdf[paths_gdf['agg_cost'] <= (i / 60)].plot(
        ax=ax,
        color='midnightblue',
        alpha=0.9,
        linewidth=0.3,
        figsize=figsize)

    ax.text(0.98, 0.59,
            '{} min.'.format(int(i / 60)),
            size=9,
            ha='right',
            transform=ax.transAxes)

    fig.savefig(
            'seq-{}.png'.format(str(i).zfill(5)),
            bbox_inches='tight',
            pad_inches=0,
            dpi=dpi)

    ax.clear()

# The range from which to create frames, in seconds, adjusted for framerate
rmin = int(amin) * 60
rmax = (int(amax) + 1) * 60
rstep = int(rmax / (mov_length * framerate))

# Multiprocessing function loop over created range
pool = Pool(cpu_count())
pool.map(create_frames, range(rmin, rmax, rstep))

connection.close()

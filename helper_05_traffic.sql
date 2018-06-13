SELECT lon, lat, osm.osm_id
FROM ways_vertices_pgr AS node
JOIN (
    SELECT edge.source_osm, edge.target_osm, edge.osm_id, tract.geoid, tract.pop
    FROM ways AS edge
    JOIN (
        SELECT geom, geoid, pop
        FROM tracts
        WHERE state = 17
        ) AS tract
    ON ST_Intersects(edge.the_geom, tract.geom)
    WHERE length_m > 15
    ORDER BY random() ^ (1.0 / pop)
    LIMIT 1000
    ) AS osm
ON osm.source_osm = node.osm_id
OR osm.target_osm = node.osm_id

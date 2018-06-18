WITH locations AS (
    SELECT unnest(array[source, target])
    FROM sample
    WHERE osm_id = {}
    GROUP BY unnest HAVING COUNT(*) = 1 OR COUNT(*) = 3
)
SELECT d.osm_id, start_vid, end_vid, tag_id,
    agg_cost, maxspeed, length, polyline,
    origins.lat AS olat, origins.lon AS olon,
    dests.lat AS dlat, dests.lon AS dlon
FROM (
    SELECT
        osm_id,
        max(start_vid) AS start_vid,
        max(end_vid) AS end_vid,
        max(c.tag_id) AS tag_id,
        max(c.maxspeed) AS maxspeed,
        max(agg_cost) AS agg_cost,
        sum(length_m) * 6.2e-4 AS length,
        ST_AsEncodedPolyline(
            ST_SetSRID(ST_MakeLine(b.the_geom), 4326)) AS polyline
    FROM pgr_dijkstra('
        SELECT gid id, source, target,
        CASE WHEN cost < 0
            THEN 1e8
            ELSE length_m * 6.2e-4 * 60 / maxspeed END AS cost,
        CASE WHEN reverse_cost < 0
            THEN 1e8
            ELSE length_m * 6.2e-4 * 60 / maxspeed END AS reverse_cost
        FROM sample
        JOIN configuration c ON sample.tag_id = c.tag_id
        ', (
        SELECT array_agg(source)
        FROM sample
        WHERE source IN (SELECT * FROM locations)
        AND osm_id = {}
        ), (
        SELECT array_agg(target)
        FROM sample
        WHERE target IN (SELECT * FROM locations)
        AND osm_id = {}
        )
    ) a
    JOIN ways b                    ON a.edge      = b.gid
    JOIN configuration c           ON b.tag_id    = c.tag_id
    GROUP BY b.osm_id
    ORDER BY b.osm_id
) d
JOIN ways_vertices_pgr origins ON start_vid = origins.id
JOIN ways_vertices_pgr dests   ON end_vid   = dests.id


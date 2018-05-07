INSERT INTO paths (origin, destination, agg_cost, path_seq, the_geom)
SELECT DISTINCT ON (a.edge)
origins.geoid origin, destinations.geoid destination, a.agg_cost, a.path_seq, b.the_geom
FROM pgr_dijkstra('
  WITH w AS (
    SELECT ST_Buffer(ST_Envelope(ST_Union(centroid)), 0.025) u 
    FROM   tracts
    WHERE  osm_nn IS NOT NULL
    )
  SELECT gid id, source, target,
  CASE WHEN cost         < 0 
    THEN 1e8 
    ELSE length_m * 6.2e-4 * 60 / maxspeed END AS cost,
  CASE WHEN reverse_cost < 0
    THEN 1e8
    ELSE length_m * 6.2e-4 * 60 / maxspeed END AS reverse_cost
  FROM ways
  JOIN configuration ON 
    ways.tag_id = configuration.tag_id
  WHERE ST_Intersects(the_geom, (SELECT u FROM w))
  ', (
  SELECT array_agg(osm_nn) A 
  FROM tracts
  WHERE osm_nn IS NOT NULL 
  AND state = $state AND county = $county AND tract = $tract), (
  SELECT array_agg(osm_nn) 
  FROM tracts
  WHERE osm_nn IS NOT NULL
  AND ST_Contains((
    SELECT geom_buffer
    FROM counties 
    WHERE state = $state AND county = $county),
  centroid)
  ),
  TRUE
) a
JOIN tracts origins       ON start_vid = origins.osm_nn
JOIN tracts destinations  ON end_vid   = destinations.osm_nn
JOIN ways b               ON a.edge    = b.gid
ORDER BY a.edge
;

INSERT INTO paths (origin, destination, agg_cost, path_seq, the_geom)
SELECT 
origins.geoid origin, destinations.geoid destination, a.agg_cost, a.path_seq, b.the_geom
FROM pgr_dijkstra('
  WITH w AS (
    SELECT ST_Buffer(ST_Envelope(ST_Union(centroid)), 0.025) u 
    FROM   tracts
    WHERE  osm_nn IS NOT NULL
    )
  SELECT gid id, source, target, 
  CASE WHEN cost         < 0 
    THEN 1e8 
    ELSE length_m * 6.2e-4 * 60 / maxspeed END AS cost,
  CASE WHEN reverse_cost < 0
    THEN 1e8
    ELSE length_m * 6.2e-4 * 60 / maxspeed END AS reverse_cost
  FROM ways
  JOIN configuration ON 
    ways.tag_id = configuration.tag_id
  WHERE ST_Intersects(the_geom, (SELECT u FROM w))
  ', (
  SELECT array_agg(osm_nn) A 
  FROM tracts
  WHERE osm_nn IS NOT NULL 
  AND state = $state AND county = $county AND tract = $tract), (
  SELECT array_agg(osm_nn) 
  FROM tracts t
  WHERE (osm_nn IS NOT NULL
  AND NOT EXISTS (
    SELECT * FROM paths p
    WHERE p.destination = t.geoid)
  AND ST_Contains((
    SELECT geom_buffer
    FROM counties
    WHERE state = $state AND county = $county),
  centroid))
  OR (osm_nn IS NOT NULL
  AND t.geoid IN (
    SELECT m.destination 
    FROM (
      SELECT DISTINCT ON (destination) destination, agg_cost
      FROM paths 
      ORDER BY destination, agg_cost DESC) m
    JOIN times ti ON (m.destination = ti.destination)
    WHERE m.agg_cost < ti.agg_cost
    AND ti.origin = $state$county$tract))
  ),
  TRUE
) a
JOIN tracts origins       ON start_vid = origins.osm_nn
JOIN tracts destinations  ON end_vid   = destinations.osm_nn
JOIN ways b               ON a.edge    = b.gid
;


INSERT INTO times (origin, destination, agg_cost)
SELECT origins.geoid origin, destinations.geoid destination, agg_cost
FROM pgr_dijkstraCost('
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
  AND state = $state AND county = $county), (
  SELECT array_agg(osm_nn) 
  FROM tracts
  WHERE osm_nn IS NOT NULL
  AND ST_Contains((
    SELECT geom_buffer
    FROM counties 
    WHERE state = $state AND county = $county),
  centroid)
  ),
  FALSE
) 
JOIN tracts origins      ON start_vid = origins.osm_nn
JOIN tracts destinations ON end_vid   = destinations.osm_nn
ORDER BY origin, destination
;

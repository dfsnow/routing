DROP TABLE IF EXISTS sample;

CREATE TABLE sample AS (
    SELECT *
    FROM ways
    WHERE osm_id IN (
        SELECT osm_id
        FROM (
            SELECT osm_id, tag_id,
            ROW_NUMBER() OVER (
                PARTITION BY tag_id
                ORDER BY random() ^ (1.0 / pop)) AS pos
            FROM ways
            JOIN (
                SELECT geom, geoid, pop
                FROM tracts
            ) AS tract
            ON ST_Intersects(ways.the_geom, tract.geom)
            WHERE tag_id >= 100 AND tag_id <= 200
            AND osm_id IN (
                SELECT osm_id
                FROM ways
                GROUP BY osm_id HAVING COUNT(*) >= 5
            )
        ) a
        WHERE pos <= 20
        ORDER BY osm_id
    )
);

DELETE FROM sample
WHERE osm_id NOT IN (
    SELECT osm_id FROM (
        SELECT osm_id, unnest(array[source, target])
        FROM sample
        GROUP BY osm_id, unnest HAVING COUNT(*) = 1
    ) a
)
OR osm_id IN (
    SELECT osm_id FROM (
        SELECT osm_id, unnest(array[source, target])
        FROM sample
        GROUP BY osm_id, unnest HAVING COUNT(*) > 2
    ) b
);

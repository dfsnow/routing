DROP TABLE IF EXISTS sample;

CREATE TABLE sample AS (
    WITH points AS (
        SELECT *
        FROM times 
        WHERE LPAD(origin::text, 11, '0') LIKE '$geoid%'
        ORDER BY random()
        LIMIT 20
    )
    SELECT *
    FROM points
    JOIN (
        SELECT geoid AS ogeoid, ST_X(centroid) AS olon, ST_Y(centroid) AS olat
        FROM tracts
    ) AS origin
    ON (points.origin = origin.ogeoid)
    JOIN (
        SELECT geoid AS dgeoid, ST_X(centroid) AS dlon, ST_Y(centroid) AS dlat
        FROM tracts
    ) AS destination
    ON (points.destination = destination.dgeoid)
)




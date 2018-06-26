ALTER TABLE tracts
ADD COLUMN IF NOT EXISTS osm_nn BIGINT DEFAULT NULL;
UPDATE tracts SET osm_nn = NULL;

CREATE OR REPLACE FUNCTION DoKnnMatch(init_tol float8, step_tol float8, max_tol float8)
RETURNS float8 AS $$
DECLARE
    tol float8;
    sql varchar;
BEGIN
    tol := init_tol;
    LOOP
        EXECUTE '
            UPDATE tracts SET osm_nn = id FROM (
                SELECT DISTINCT ON (tracts.geoid) tracts.geoid, id
                FROM tracts, ways_vertices_pgr
                WHERE osm_nn IS NULL AND
                ST_DWithin(centroid, the_geom, ' || tol || ')
                ORDER BY tracts.geoid, centroid <-> the_geom) knn
            WHERE tracts.geoid = knn.geoid;
        ';

        IF tol < max_tol AND EXISTS (
            SELECT geoid FROM tracts WHERE osm_nn IS NULL)
        THEN tol := tol + step_tol;
        ELSE RETURN tol;
        END IF;
    END LOOP;
END

$$ LANGUAGE 'plpgsql' STRICT;

SELECT DoKnnMatch($knn_start, $knn_step, $knn_max);

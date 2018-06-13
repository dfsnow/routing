ALTER TABLE tracts ADD COLUMN IF NOT EXISTS pop bigint;

UPDATE tracts a
SET centroid = c.centroid,
    pop      = c.pop
FROM (
    SELECT tract_id, avg(tract_pop) AS pop, ST_Transform(
        ST_SetSRID(ST_MakePoint(
            sum(ST_X(ST_Transform(b.centroid,2163))*b.block_weight),
            sum(ST_Y(ST_Transform(b.centroid,2163))*b.block_weight)),
        2163), 4326) AS centroid
    FROM blocks b
    GROUP BY tract_id) c
WHERE a.geoid = c.tract_id
AND c.centroid IS NOT NULL;

CREATE INDEX ON "public"."tracts" USING GIST ("centroid");

VACUUM (FULL, VERBOSE, ANALYZE) counties;
VACUUM (FULL, VERBOSE, ANALYZE) tracts;
VACUUM (FULL, VERBOSE, ANALYZE) blocks;

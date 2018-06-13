DROP TABLE IF EXISTS times;
CREATE TABLE times (
    id              serial PRIMARY KEY,	
    origin          bigint,
    destination     bigint,
    agg_cost        float8,
    method          smallint
);

VACUUM(FULL, VERBOSE, ANALYZE) times;

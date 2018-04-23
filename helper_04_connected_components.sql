ALTER TABLE ways_vertices_pgr ADD COLUMN IF NOT EXISTS component bigint DEFAULT NULL;
ALTER TABLE ways DROP CONSTRAINT ways_source_fkey;
ALTER TABLE ways DROP CONSTRAINT ways_target_fkey;
ALTER TABLE ways DROP CONSTRAINT ways_source_osm_fkey;
ALTER TABLE ways DROP CONSTRAINT ways_target_osm_fkey;

UPDATE ways_vertices_pgr a
  SET component = b.component
  FROM pgr_connectedComponents(
    'SELECT gid id, source, target, cost, reverse_cost FROM ways') b
  WHERE a.id = b.node;

DELETE FROM ways_vertices_pgr 
  WHERE component != (
    SELECT DISTINCT ON (component) component
    FROM ways_vertices_pgr
    ORDER BY component
    LIMIT 1);

DELETE FROM ways a
  WHERE NOT EXISTS (
    SELECT * FROM ways_vertices_pgr b
    WHERE a.source_osm = b.osm_id);

ALTER TABLE ways
  ADD CONSTRAINT ways_source_fkey FOREIGN KEY (source)
  REFERENCES ways_vertices_pgr (id);
ALTER TABLE ways
  ADD CONSTRAINT ways_target_fkey FOREIGN KEY (target)
  REFERENCES ways_vertices_pgr (id);
ALTER TABLE ways
  ADD CONSTRAINT ways_source_osm_fkey FOREIGN KEY (source_osm)
  REFERENCES ways_vertices_pgr (osm_id);
ALTER TABLE ways
  ADD CONSTRAINT ways_target_osm_fkey FOREIGN KEY (target_osm)
  REFERENCES ways_vertices_pgr (osm_id);

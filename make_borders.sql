-- only run if we haven't before
IF NOT EXISTS osm_borders_linestring_gen10 DO $$ BEGIN

DROP TABLE IF EXISTS osm_borders, borders, border_attrs, border_levels, border_relations;

CREATE TABLE IF NOT EXISTS border_relations AS (
	SELECT DISTINCT
		osm_boundary.osm_id,
		osm_boundaries.member_id,
		osm_boundary.admin_level
	FROM osm_boundary LEFT JOIN osm_boundaries
		ON osm_boundary.osm_id = osm_boundaries.osm_id
	WHERE osm_boundary.admin_level IS NOT NULL
	ORDER BY member_id, admin_level, osm_id
);

-- capture the first relation among the set of relations with the 
-- lowest admin_level (NOT NULL)
CREATE TABLE IF NOT EXISTS border_levels AS (
WITH border_relations AS (
	SELECT osm_id, member_id, admin_level,
		ROW_NUMBER() OVER(PARTITION BY member_id
			ORDER BY member_id, admin_level, osm_id) as a
	FROM border_relations WHERE admin_level IS NOT NULL)
	SELECT osm_id, member_id, admin_level 
		FROM border_relations 
		WHERE a = 1
);

-- calculate maritime, disputed, and dividing_line attributes
-- NOTE: we previously removed economic exclusionary zones (EEZ; i.e., border_type=eez), but
-- do so again as a failsafe
CREATE TABLE IF NOT EXISTS border_attrs AS (
     SELECT DISTINCT
   	 osm_boundaries.member_id,
	 CASE
 	   WHEN min(osm_boundary.admin_level) <> max(osm_boundary.admin_level)
	      THEN 1
	   ELSE 0
	 END as dividing_line,
	 a.disputed,
	 a.maritime
     FROM osm_boundaries 
	LEFT JOIN (SELECT 
   	   member_id,
           CASE WHEN disputed = 'yes' THEN 1
     	          WHEN dispute = 'yes' THEN 1
     	          WHEN border_type = 'disputed' THEN 1
               ELSE 0 
           END as disputed, 
           CASE WHEN "natural" = 'coastline' THEN 1
	       	WHEN maritime = 'yes' THEN 1  
               	ELSE 0 
           END as maritime
	   FROM osm_boundaries
	 ) AS a ON osm_boundaries.member_id = a.member_id
	LEFT JOIN osm_boundary ON osm_boundaries.osm_id = osm_boundary.osm_id 
     WHERE border_type != 'eez'
     GROUP BY osm_boundaries.member_id, osm_boundaries.border_type, 
	a.disputed, a.maritime
);


-- now dump into the separate lines
CREATE TABLE IF NOT EXISTS borders AS ( 
     SELECT osm_boundaries.geometry, 
		border_levels.osm_id, 
		border_levels.admin_level, 
		border_attrs.disputed, 
		border_attrs.maritime, 
		border_attrs.dividing_line
       FROM osm_boundaries 
	INNER JOIN border_attrs ON border_attrs.member_id = osm_boundaries.member_id
	  INNER JOIN border_levels ON border_levels.member_id = osm_boundaries.member_id
);

-- since from the data pull we can reasonbly assume few or no meaningful intersections
-- we can use ST_Collect instead ST_Union
CREATE TABLE IF NOT EXISTS osm_borders AS (
     SELECT ST_LineMerge(ST_Collect(geometry)) AS geometry,
		osm_id, admin_level, disputed, maritime, dividing_line
       FROM (SELECT (ST_Dump(geometry)).geom AS geometry,
		osm_id, admin_level, disputed, maritime, dividing_line
		FROM borders) AS T
	GROUP BY osm_id, admin_level, disputed, maritime, dividing_line
);

-- clean the tables
DROP TABLE IF EXISTS borders, border_attrs, border_levels, border_relations;

-- index to speed generalization
CREATE INDEX ON osm_borders USING gist(geometry);
ANALYZE osm_borders;

-- a function to create generalized tables for lower zoom levels
-- this assumes you are operating in EPSG:3857
CREATE OR REPLACE FUNCTION create_generalized_border(t_name character varying, zoom_tolerance integer, max_admin integer)
  RETURNS VOID AS
$func$
BEGIN
EXECUTE format('DROP TABLE IF EXISTS %s;', t_name);
EXECUTE format('
CREATE MATERIALIZED VIEW %s AS (
     SELECT DISTINCT ST_Simplify(geometry, $1) AS geometry,
     	osm_id, admin_level, disputed, maritime, dividing_line
 	FROM osm_borders
     WHERE admin_level <= $2
     GROUP BY geometry, osm_id, admin_level, disputed, maritime, dividing_line
);', t_name) USING zres(zoom_tolerance), max_admin;
EXECUTE format('CREATE INDEX IF NOT EXISTS %I_geometry_idx ON %I USING gist(geometry);', t_name, t_name);
EXECUTE format('ANALYZE %I;', t_name);

END
$func$ LANGUAGE plpgsql;

-- NOTE: the 'gen#' label proceeds in reverse of zoom levels from a base zoom level 
DO $$ BEGIN
	PERFORM "create_generalized_border"('osm_borders_linestring_gen1', 14, 10);
	PERFORM "create_generalized_border"('osm_borders_linestring_gen2', 13, 10);
	PERFORM "create_generalized_border"('osm_borders_linestring_gen3', 12, 8);
	PERFORM "create_generalized_border"('osm_borders_linestring_gen4', 11, 6);
	PERFORM "create_generalized_border"('osm_borders_linestring_gen5', 10, 6);
	PERFORM "create_generalized_border"('osm_borders_linestring_gen6', 9, 4);
	PERFORM "create_generalized_border"('osm_borders_linestring_gen7', 8, 4);
	PERFORM "create_generalized_border"('osm_borders_linestring_gen8', 7, 4);
	PERFORM "create_generalized_border"('osm_borders_linestring_gen9', 6, 4);
	PERFORM "create_generalized_border"('osm_borders_linestring_gen10', 5, 2);
END $$;


-- end of boundaries file
END $$;


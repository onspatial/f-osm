CREATE TABLE places_have_adddress AS SELECT p.*, n.*, (n.lat::numeric  / 10000000) AS lat_deg, (n.lon::numeric  / 10000000) AS lon_deg FROM place p JOIN planet_osm_nodes n ON n.id = p.osm_id WHERE p.address IS NOT NULL ;


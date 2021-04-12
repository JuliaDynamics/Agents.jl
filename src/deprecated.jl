# 4.0 Deprecations
@deprecate space_neighbors nearby_ids
@deprecate node_neighbors nearby_positions
@deprecate get_node_contents ids_in_position
@deprecate get_node_agents agents_in_position
@deprecate pick_empty random_empty
@deprecate find_empty_nodes empty_positions
@deprecate has_empty_nodes has_empty_positions
@deprecate nodes positions

# 4.2 Deprecations
@deprecate fastest Schedulers.fastest
@deprecate by_id Schedulers.by_id
@deprecate as_added Schedulers.by_id
@deprecate random_activation Schedulers.randomly
@deprecate partial_activation Schedulers.partially
@deprecate property_activation Schedulers.by_property
@deprecate by_type Schedulers.by_type

@deprecate osm_random_road_position OSM.random_road_position
@deprecate osm_plan_route OSM.plan_route
@deprecate osm_map_coordinates OSM.map_coordinates
@deprecate osm_road_length OSM.road_length
@deprecate osm_random_route! OSM.random_route!
@deprecate osm_latlon OSM.latlon
@deprecate osm_intersection OSM.intersection
@deprecate osm_road OSM.road
@deprecate move_agent!(a, model::ABM{<:OpenStreetMapSpace}, distance) move_along_route!(a, model, distance)

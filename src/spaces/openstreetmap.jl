export OpenStreetMapSpace, OpenStreetMapPath, OSMAgent, OSMSpace
export OSM # submodule

"""
    OpenStreetMapPath

This struct stores information about the path of an agent via route planning.
It also serves as developer's docs for some of the internals of `OpenStreetMapSpace`.

## Storage of map nodes
Each node has a node ID from the OpenStreetMap API.
The map is stored as a `Graph` by `LightOSM`, and hence each node also has a vertex index
corresponding to the vertex representing it in this graph. Hence each node can be referred
to by either the node ID or its graph index, and we can convert either way, using
the function `LightOSM.index_to_node`.
We use graph vertex indices consistently in [`OpenStreetMapSpace`](@ref OSM.OpenStreetMapSpace), because
we access graph data more often than OSM data.

## Fields of `OpenStreetMapPath`
- `route::Vector{Int}`: Vertex indices along the planned route. They are
  actually stored in inverse sequence, from `dest` to `start`, because it is more efficient
  to pop the off this way while traversing the route.
- `start::Tuple{Int,Int,Float64}`: Initial position of the agent.
- `dest::Tuple{Int,Int,Float64}`: Destination.
- `return_route::Vector{Int}`: Same as `route` but for the return trip.
- `has_to_return::Bool`: `true` if there is an actual return trip.
"""
struct OpenStreetMapPath
    route::Vector{Int}
    start::Tuple{Int, Int, Float64}
    dest::Tuple{Int, Int, Float64}
    return_route::Vector{Int}
    has_to_return::Bool
end

"""
    OpenStreetMapSpace(path::AbstractString; kwargs...)

Create a space residing on the Open Street Map (OSM) file provided via `path`.
This space represents the underlying map as a *continuous* entity choosing accuracy over
performance. The map is represented as a graph, consisting of nodes connected by edges.
Nodes are not necessarily intersections, and there may be multiple nodes on a road joining
two intersections.
Agents move along the available roads of the map using routing, see below.

An example of using Open Street Map spaces can be found in the [Zombie Outbreak](@ref osm_examle) tutorial.

## The `OSMAgent`

The base properties for an agent residing on an `OSMSpace` are as follows:
```julia
mutable struct Agent <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int,Float64}
end
```
which are captured by the `OSMAgent` basic agent type.
Current `pos`ition tuple is represented as
(first intersection index, second intersection index, distance travelled).
The indices are the indices of the nodes of the graph that internally represents the map.
Functions like [`OSM.nearest_node`](@ref) or [`OSM.nearest_road`](@ref)
can help find those node indices from a (lon, lat) real world coordinate.
The distance travelled is in the units of `weight_type`. This ensures that the map
is a *continuous* kind of space, as an agent can truly be at any possible point on
an existing road.

## Obtaining map files

Maps files can be downloaded using the functions provided by
[LightOSM.jl](https://github.com/DeloitteDigitalAPAC/LightOSM.jl).
The function you'd typically want to use is `download_osm_network`:

```julia
LightOSM.download_osm_network(
    :place_name;
    place_name = "London",
    save_to_file_location = "london.json"
)
```

The length of an edge between two nodes is specified in the units of the
map's `weight_type` as listed in the documentation for
[`LightOSM.OSMGraph`](https://deloittedigitalapac.github.io/LightOSM.jl/docs/types/#LightOSM.OSMGraph).
The possible `weight_type`s are:
- `:distance`: The distance in kilometers of an edge
- `:time`: The time in hours to travel along an edge at the maximum speed allowed on that road
- `:lane_efficiency`: Time scaled by number of lanes

The default `weight_type` used is `:distance`.

All `kwargs` are propagated to
[`LightOSM.graph_from_file`](https://deloittedigitalapac.github.io/LightOSM.jl/docs/create_graph/#LightOSM.graph_from_file).

## Routing with OSM

You can use [`OSM.plan_route!`](@ref) or [`OSM.plan_random_route!`](@ref) with open street maps!
To actually move along a planned route use [`OSM.move_along_route!`](@ref).

## Additional functionality

Additional functionality specific to Open Street Map spaces is contained in the
submodule [`OSM`](@ref).

- [`OSM.test_map`](@ref)
- [`OSM.random_road_position`](@ref)
- [`OSM.plan_route!`](@ref)
- [`OSM.plan_random_route!`](@ref)
- [`OSM.move_along_route!`](@ref)
- [`OSM.distance`](@ref)
- [`OSM.lonlat`](@ref)
- [`OSM.nearest_node`](@ref)
- [`OSM.road_length`](@ref)
- [`OSM.route_length`](@ref)
- [`OSM.get_geoloc`](@ref)
- [`OSM.same_position`](@ref)
- [`OSM.same_road`](@ref)
- [`OSM.closest_node_on_edge`](@ref)
"""
struct OpenStreetMapSpace{G} <: Agents.AbstractSpace
    map::G # <: OSMGraph
    s::Vector{Vector{Int}}
    routes::Dict{Int, OpenStreetMapPath} # maps agent ID to corresponding path
end
const OSMSpace = OpenStreetMapSpace

function OpenStreetMapSpace(args...; kw...)
    error("Package `LightOSM` needs to be loaded to access `OpenStreetMapSpace`")
end


# NOTE: All positions are indexed by vertex number and _not_ OSM node id
"""
    OSMAgent <: AbstractAgent
The minimal agent struct for usage with [`OpenStreetMapSpace`](@ref).
It has an additional field `pos::Tuple{Int,Int,Float64}`. See also [`@agent`](@ref).
"""
Agents.@agent struct OSMAgent(NoSpaceAgent)
    pos::Tuple{Int, Int, Float64}
end

# Now all OSM-specific functions go into a submodule
"""
    Agents.OSM
Extension module for functionality related to [`OpenStreetMapSpace`](@ref).
See the docstring of the space for more info.
"""
module OSM

    # Space specifics:
    export test_map,
        random_road_position,
        plan_route!,
        plan_random_route!,
        move_along_route!,
        distance,
        road_length,
        route_length,
        lonlat,
        nearest_node,
        nearest_road,
        road_length,
        route_length,
        same_position,
        closest_node_on_edge,
        same_road


    """
        OSM.test_map()
    
    Download a small test map of [Göttingen](https://www.openstreetmap.org/export#map=16/51.5333/9.9363)
    as an artifact. Return a path to the downloaded file.
    
    Using this map requires `network_type = :none` to be passed as a keyword
    to [`OpenStreetMapSpace`](@ref OSM.OpenStreetMapSpace). The unit of distance used for this map is `:time`.
    """
    function test_map end

    """
        OSM.random_road_position(model::ABM{<:OpenStreetMapSpace})
    
    Similar to [`random_position`](@ref), but rather than providing only intersections, this method
    returns a location somewhere on a road heading in a random direction.
    """
    function random_road_position end

    """
        OSM.plan_random_route!(agent, model::ABM{<:OpenStreetMapSpace}; kwargs...) → success
    
    Plan a new random route for the agent, by selecting a random destination and
    planning a route from the agent's current position. Overwrite any existing route.
    
    The keyword `limit = 10` specifies the limit on the number of attempts at planning
    a random route, as no connection may be possible given the random destination.
    Return `true` if a route was successfully planned, `false` otherwise.
    All other keywords are passed to [`plan_route!`](@ref)
    """
    function plan_random_route! end


    """
        OSM.plan_route!(agent, dest, model::ABM{<:OpenStreetMapSpace}; kw...)
    
    Plan a route from the current position of `agent` to the location specified in `dest`, which
    can be an intersection or a point on a road. Overwrite any existing route.
    
    Return `true` if a path to `dest` exists, and hence the route planning was successful.
    Otherwise return `false`. When `dest` is an invalid position, i.e. if it contains node
    indices that are not in the graph, or if the distance along the road is not between zero and
    the length of the road, return `false` as well.
    
    
    ## Keyword arguments
    
    * `return_trip = true`: if true, a route will be planned from start ⟶ finish ⟶ start.
        Specifying `return_trip = true` also requires the existence of a return path for a route to
        be planned.
    * All other keywords are passed to
        [`LightOSM.shortest_path`](https://deloittedigitalapac.github.io/LightOSM.jl/docs/shortest_path/#LightOSM.shortest_path).
    """
    function plan_route! end


    """
        OSM.distance(pos_1, pos_2, model::ABM{<:OpenStreetMapSpace}; kwargs...)
    
    Return the distance between the two positions along the shortest path joining them in the given
    model. Return `Inf` if no such path exists.
    
    All keywords are passed to
    [`LightOSM.shortest_path`](https://deloittedigitalapac.github.io/LightOSM.jl/docs/shortest_path/#LightOSM.shortest_path).
    """
    function distance end

    """
        OSM.lonlat(pos, model)
        OSM.lonlat(agent, model)
    
    Return `(longitude, latitude)` of current road or intersection position.
    """
    function lonlat end

    """
        OSM.nearest_node(lonlat::Tuple{Float64,Float64}, model::ABM{<:OpenStreetMapSpace})
    
    Return the nearest intersection position to **(longitude, latitude)**.
    Quicker, but less precise than [`OSM.nearest_road`](@ref).
    """
    function nearest_node end

    """
        OSM.nearest_road(lonlat::Tuple{Float64,Float64}, model::ABM{<:OpenStreetMapSpace})
    
    Return a location on a road nearest to **(longitude, latitude)**. Slower, but more
    precise than [`OSM.nearest_node`](@ref).
    """
    function nearest_road end

    """
        OSM.road_length(start::Int, finish::Int, model)
        OSM.road_length(pos::Tuple{Int,Int,Float64}, model)
    
    Return the road length between two intersections. This takes into account the
    direction of the road, so `OSM.road_length(pos_1, pos_2, model)` may not be the
    same as `OSM.road_length(pos_2, pos_1, model)`. Units of the returned quantity
    are as specified by the underlying graph's `weight_type`. If `start` and `finish`
    are the same or `pos[1]` and `pos[2]` are the same, then return 0.
    """
    function road_length end

    """
        OSM.route_length(agent, model::ABM{<:OpenStreetMapSpace})
    Return the length of the route planned for the given `agent`, correctly taking
    into account the amount of route already traversed by the `agent`.
    Return 0 if `OSM.is_stationary(agent, model)`.
    """
    function route_length end

    function is_stationary end

    """
        OSM.get_geoloc(pos::Int, model::ABM{<:OpenStreetMapSpace})
    
    Return `GeoLocation` corresponding to node `pos`.
    """
    function get_geoloc end

    """
        OSM.same_position(a::Tuple{Int,Int,Float64}, b::Tuple{Int,Int,Float64}, model::ABM{<:OpenStreetMapSpace})
    
    Return `true` if the given positions `a` and `b` are (approximately) identical
    """
    function same_position end


    """
        OSM.same_road(a::Tuple{Int,Int,Float64}, b::Tuple{Int,Int,Float64})
    
    Return `true` if both points lie on the same road of the graph
    """
    function same_road end

    """
        OSM.closest_node_on_edge(a::Tuple{Int,Int,Float64}, model::ABM{<:OpenStreetMapSpace})
    
    Return the node that the given point is closest to on its edge.
    """
    function closest_node_on_edge end


    """
        OSM.move_along_route!(agent, model::ABM{<:OpenStreetMapSpace}, distance::Real) → remaining
    
    Move an agent by `distance` along its planned route. Units of distance are as specified
    by the underlying graph's `weight_type`. If the provided `distance` is greater than the
    distance to the end of the route, return the remaining distance. Otherwise, return `0`.
    `0` is also returned if `is_stationary(agent, model)`.
    """
    function move_along_route! end


end # submodule

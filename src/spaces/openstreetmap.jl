export OpenStreetMapSpace, OSMSpace, OSM

"""
    OSM
Submodule for functionality related to `OpenStreetMapSpace`.
See the docstring of the space for more info.
"""
module OSM # OpenStreetMap
using Agents
using LightOSM
using Graphs
using LazyArtifacts
using LinearAlgebra: dot, norm
using DataStructures
using Downloads

export test_map,
    random_road_position,
    plan_route!,
    distance,
    road_length,
    plan_random_route!,
    lonlat,
    nearest_node,
    nearest_road,
    same_position,
    same_road,
    download_osm_network    # re-exported from LightOSM.jl


# Stores information about an agent's path
struct OpenStreetMapPath
    route::Vector{Int}      # node IDs along path from `start` to `dest`
    start::Tuple{Int,Int,Float64} # Initial position of the agent
    dest::Tuple{Int,Int,Float64}    # Destination. `dest[1] == dest[2]` if this is an intersection
    return_route::Vector{Int}   # node IDs along path from `dest` to `start`
    has_to_return::Bool
end

# NOTE: All positions are indexed by vertex number and _not_ node id

"""
    OpenStreetMapSpace(path::AbstractString; kwargs...)
Create a space residing on the Open Street Map (OSM) file provided via `path`.
A sample file is provided using [`OSM.test_map`](@ref). Additional maps can
be downloaded using the [functions provided by LightOSM.jl](https://deloittedigitalapac.github.io/LightOSM.jl/docs/download_network/).
The functionality related to Open Street Map spaces is in the submodule `OSM`.
Agents.jl also re-exports [`OSM.download_osm_network`](@ref). An example usage
to download the map of London to "london.json":

```julia
OSM.download_osm_network(
    :place_name;
    place_name = "London",
    save_to_file_location = "london.json"
)
```

This space represents the underlying map as a *continuous* entity choosing accuracy over
performance. The map is represented as a graph, consisting of nodes connected by edges. Nodes
are not necessarily intersections, and there may be multiple nodes on a road joining two
intersections. Agents move along the available roads of the map using routing, see below.

The length of an edge between two nodes is specified in the units of the
map's `weight_type` as listed in the documentation for
[`LightOSM.OSMGraph`](https://deloittedigitalapac.github.io/LightOSM.jl/docs/types/#LightOSM.OSMGraph).
The possible `weight_type`s are:
- `:distance`: The distance in kilometers of an edge
- `:time`: The time in hours to travel along an edge at the maximum speed allowed on that road
- `:lane_efficiency`: Time scaled by number of lanes

The default `weight_type` used is `:distance`.

An example of its usage can be found in [Zombie Outbreak](@ref).

All `kwargs` are propagated to
[`LightOSM.graph_from_file`](https://deloittedigitalapac.github.io/LightOSM.jl/docs/create_graph/#LightOSM.graph_from_file).

## The `OSMAgent`

The base properties for an agent residing on an `OSMSpace` are as follows:
```julia
mutable struct Agent <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int,Float64}
end
```

Current `pos`ition tuple is represented as
`(first intersection index, second intersection index, distance travelled)`.
The distance travelled is in the units of `weight_type`. This ensures that the map
is a *continuous* kind of space, as an agent can truly be at any possible point on
an existing road.

Use [`OSMAgent`](@ref) for convenience.

## Routing

There are two ways to generate a route, depending on the situation.
1. Use [`plan_route!`](@ref) to plan a route from an agent's current position to a target
   destination. This also has the option of planning a return trip.
2. [`plan_random_route!`](@ref), choses a new random destination and plans a path to it.

Both of these functions override any pre-existing route that may exist for an agent.
To actually move along a planned route use [`move_along_route!`](@ref).
"""
struct OpenStreetMapSpace <: Agents.AbstractSpace
    map::OSMGraph
    s::Vector{Vector{Int}}
    routes::Dict{Int,OpenStreetMapPath} # maps agent ID to corresponding path
end

function OpenStreetMapSpace(
    path::AbstractString;
    kwargs...
)
    m = graph_from_file(path; weight_type = :distance, kwargs...)
    agent_positions = [Int[] for _ in 1:Agents.nv(m.graph)]
    return OpenStreetMapSpace(m, agent_positions, Dict())
end

function Base.show(io::IO, s::OpenStreetMapSpace)
    print(
        io,
        "OpenStreetMapSpace with $(length(s.map.highways)) ways " *
        "and $(length(s.map.nodes)) nodes",
    )
end

"""
    OSM.test_map()

Download a small test map of [Göttingen](https://www.openstreetmap.org/export#map=16/51.5333/9.9363)
as an artifact. Return a path to the downloaded file.

Using this map requires `network_type = :none` to be passed as a keyword
to [`OSMSpace`](@ref). The unit of distance used for this map is `:time`.
"""
test_map() = joinpath(artifact"osm_map_gottingen", "osm_map_gottingen.json")

#######################################################################################
# Custom functions for OSMSpace
#######################################################################################

# EXPORTED
"""
    OSM.random_road_position(model::ABM{<:OpenStreetMapSpace})

Similar to [`random_position`](@ref), but rather than providing only intersections, this method
returns a location somewhere on a road heading in a random direction.
"""
function random_road_position(model::ABM{<:OpenStreetMapSpace})
    # pick a random source and destination, and then a random distance on that edge
    s = Int(rand(model.rng, 1:Agents.nv(model)))
    if isempty(all_neighbors(model.space.map.graph, s))
        return (s, s, 0.0)
    end
    d = Int(rand(model.rng, all_neighbors(model.space.map.graph, s)))
    dist = rand(model.rng) * road_length(s, d, model)
    return (s, d, dist)
end

"""
    OSM.plan_random_route!(agent, model::ABM{<:OpenStreetMapSpace}; kwargs...) → success

Plan a new random route for the agent, by selecting a random destination and
planning a route from the agent's current position. Overwrite any existing route.

The keyword `limit = 10` specifies the limit on the number of attempts at planning
a random route, as no connection may be possible given the random start and end.
Return `true` if a route was successfully planned, `false` otherwise.
All other keywords are passed to [`plan_route!`](@ref)
"""
function plan_random_route!(
    agent::A,
    model::ABM{<:OpenStreetMapSpace,A};
    return_trip = false,
    limit = 10,
    kwargs...
) where {A<:AbstractAgent}
    tries = 0
    while tries < limit && !plan_route!(
        agent,
        random_road_position(model),
        model;
        return_trip,
        kwargs...
    )
        tries += 1
    end

    return tries < limit
end

"""
    plan_route!(agent, dest, model::ABM{<:OpenStreetMapSpace};
                   return_trip = false, kwargs...)

Plan a route from the current position of `agent` to the location specified in `dest`, which
can be an intersection or a point on a road.

If `return_trip = true`, a route will be planned from start ⟶ finish ⟶ start. All other
keywords are passed to
[`LightOSM.shortest_path`](https://deloittedigitalapac.github.io/LightOSM.jl/docs/shortest_path/#LightOSM.shortest_path).

Returns `true` if a path to `dest` exists, and `false` if it doesn't. Specifying
`return_trip = true` also requires the existence of a return path for a route to be
planned.
"""
function Agents.plan_route!(
    agent::A,
    dest::Tuple{Int,Int,Float64},
    model::ABM{<:OpenStreetMapSpace,A};
    return_trip = false,
    kwargs...
) where {A<:AbstractAgent}
    delete!(model.space.routes, agent.id)   # clear old route

    same_position(agent.pos, dest, model) && return true

    if same_road(agent.pos, dest)
        if agent.pos[1] == dest[2] # opposite orientations
            dest = get_reverse_direction(dest, model)
        end

        if agent.pos[3] > dest[3]   # wrong orientation
            move_agent!(agent, get_reverse_direction(agent.pos, model), model)
            dest = get_reverse_direction(dest, model)
        end

        model.space.routes[agent.id] = OpenStreetMapPath(
            Int[],
            agent.pos,
            dest,
            Int[],
            return_trip,
        )

        return true
    end

    start_node = closest_node_on_edge(agent.pos, model)

    end_node = closest_node_on_edge(dest, model)

    if start_node == end_node   # LightOSM doesn't like this case
        if agent.pos[1] == agent.pos[2] # start at node
            end_node == dest[2] && (dest = get_reverse_direction(dest, model))
            move_agent!(agent, (dest[1], dest[2], 0.0), model)
            model.space.routes[agent.id] = OpenStreetMapPath(
                Int[],
                agent.pos,
                dest,
                return_trip ? Int[agent.pos[1]] : Int[],
                return_trip,
            )
            return true
        end
        if dest[1] == dest[2]   # end at node
            start_node == agent.pos[1] && move_agent!(agent, get_reverse_direction(agent.pos, model), model)
            dest = (agent.pos[1], agent.pos[2], road_length(agent.pos, model))
            model.space.routes[agent.id] = OpenStreetMapPath(
                Int[],
                agent.pos,
                dest,
                Int[],
                return_trip,
            )
            return true
        end
        # start and end in middle of edge, but edges have common node
        start_node == agent.pos[1] &&
            move_agent!(agent, get_reverse_direction(agent.pos, model), model)
        end_node == dest[2] &&
            (dest = get_reverse_direction(dest, model))
        model.space.routes[agent.id] = OpenStreetMapPath(
            Int[start_node],
            agent.pos,
            dest,
            return_trip ? Int[start_node] : Int[],
            return_trip,
        )
        return true
    end

    route = Int[]
    try
        # TODO: Try-catch blocks are bad for performance. This has to be changed
        # to something else in the future.
        route = shortest_path(
            model.space.map,
            model.space.map.index_to_node[start_node],
            model.space.map.index_to_node[end_node];
            kwargs...
        )
    catch
        return false
    end

    for i in 1:length(route)
        route[i] = Int(model.space.map.node_to_index[route[i]])
    end

    reverse!(route)

    if agent.pos[1] == agent.pos[2] ||
       length(route) > 1 && (
           route[end] == agent.pos[1] && route[end-1] == agent.pos[2] ||
           route[end] == agent.pos[2] && route[end-1] == agent.pos[1]
       )
        pop!(route)
    end

    if length(route) > 1 && route[end] == agent.pos[1]
        move_agent!(agent, get_reverse_direction(agent.pos, model), model)
    end

    return_route = Int[]
    if return_trip
        try
            # TODO: Try-catch blocks are bad for performance. This has to be changed
            # to something else in the future.
            return_route = shortest_path(
                model.space.map,
                model.space.map.index_to_node[end_node],
                model.space.map.index_to_node[start_node];
                kwargs...
            )
        catch
            return false
        end

        for i in 1:length(return_route)
            return_route[i] = Int(model.space.map.node_to_index[return_route[i]])
        end

        reverse!(return_route)
        if dest[1] == dest[2] ||
            length(return_route) > 1 && (
                return_route[end] == dest[1] && return_route[end-1] == dest[2] ||
                return_route[end] == dest[2] && return_route[end-1] == dest[1]
            )
            pop!(return_route)
        end
    end

    model.space.routes[agent.id] = OpenStreetMapPath(
        route,
        agent.pos,
        dest,
        return_route,
        return_trip,
    )
    return true
end

# Allows passing destination as an index
Agents.plan_route!(agent::A, dest::Int, model; kwargs...) where {A<:AbstractAgent} =
    plan_route!(agent, (dest, dest, 0.0), model; kwargs...)

"""
    OSM.distance(pos_1, pos_2, model::ABM{<:OpenStreetMapSpace}; kwargs...)

Return the distance between the two positions along the shortest path joining them in the given
model. Returns `Inf` if no such path exists.

All keywords are passed to
[`LightOSM.shortest_path`](https://deloittedigitalapac.github.io/LightOSM.jl/docs/shortest_path/#LightOSM.shortest_path).
"""
function distance(
    pos_1::Tuple{Int,Int,Float64},
    pos_2::Tuple{Int,Int,Float64},
    model::ABM{<:OpenStreetMapSpace};
    kwargs...
)
    # positions are identical
    same_position(pos_1, pos_2, model) && return 0.0

    # positions on same road
    if same_road(pos_1, pos_2)
        if pos_1[1] == pos_2[1]
            return abs(pos_1[3] - pos_2[3])
        else
            return abs(pos_1[3] - road_length(pos_1, model) + pos_2[3])
        end
    end

    # starting vertex
    st_node = closest_node_on_edge(pos_1, model)

    # ending vertex
    en_node = closest_node_on_edge(pos_2, model)

    # Case where they are same
    if st_node == en_node
        r1 = (pos_1[1] == pos_1[2] ? 0.0 : pos_1[3])
        r2 = (pos_2[1] == pos_2[2] ? 0.0 : pos_2[3])
        if pos_1[1] != pos_1[2] && st_node == pos_1[2]
            r1 = road_length(pos_1, model) - r1
        end
        if pos_2[1] != pos_2[2] && en_node == pos_2[2]
            r2 = road_length(pos_2, model) - r2
        end
        return r1 + r2
    end

    route = Int[]

    # get route
    try
        route = shortest_path(
            model.space.map,
            model.space.map.index_to_node[st_node],
            model.space.map.index_to_node[en_node];
            kwargs...
        )
    catch
        return Inf
    end

    # distance along route
    dist = sum(weights_from_path(model.space.map, route))

    # cases where starting or ending position is partway along a road
    # route may or may not pass through that road, so all cases need to be handled
    if pos_1[1] != pos_1[2]
        if route[1] == pos_1[1]
            if route[2] == pos_1[2]
                dist -= pos_1[3]
            else
                dist += pos_1[3]
            end
        else
            if route[2] == pos_1[1]
                dist -= road_length(pos_1, model) - pos_1[3]
            else
                dist += road_length(pos_1, model) - pos_1[3]
            end
        end
    end

    if pos_2[1] != pos_2[2]
        if route[end] == pos_2[1]
            if route[end-1] == pos_2[2]
                dist -= pos_2[3]
            else
                dist += pos_2[3]
            end
        else
            if route[end-1] == pos_2[1]
                dist -= road_length(pos_2, model) - pos_2[3]
            else
                dist += road_length(pos_2, model) - pos_2[3]
            end
        end
    end

    return dist
end

function distance(
    pos_1::Int,
    pos_2::Tuple{Int,Int,Float64},
    model::ABM{<:OpenStreetMapSpace};
)
    distance((pos_1, pos_1, 0.0), pos_2, model)
end

function distance(
    pos_1,
    pos_2::Int,
    model::ABM{<:OpenStreetMapSpace}
)
    distance(pos_1, (pos_2, pos_2, 0.0), model)
end

"""
    OSM.lonlat(pos, model)
    OSM.lonlat(agent, model)

Return `(longitude, latitude)` of current road or intersection position.
"""
lonlat(pos::Int, model::ABM{<:OpenStreetMapSpace}) =
    Tuple(reverse(model.space.map.node_coordinates[pos]))

function lonlat(pos::Tuple{Int,Int,Float64}, model::ABM{<:OpenStreetMapSpace})
    # extra checks to ensure consistency between both versions of `lonlat`
    if pos[3] == 0.0 || pos[1] == pos[2]
        return lonlat(pos[1], model)
    elseif pos[3] == road_length(pos, model)
        return lonlat(pos[2], model)
    else
        gloc1 = get_geoloc(pos[1], model)
        gloc2 = get_geoloc(pos[2], model)
        dist = norm(LightOSM.to_cartesian(gloc1) .- LightOSM.to_cartesian(gloc2))
        dir = heading(gloc1, gloc2)
        geoloc = calculate_location(gloc1, dir, pos[3] / road_length(pos, model) * dist)
        return (geoloc.lon, geoloc.lat)
    end
end

lonlat(agent::A, model::ABM{<:OpenStreetMapSpace,A}) where {A<:AbstractAgent} =
    lonlat(agent.pos, model)

latlon(pos::Int, model::ABM{<:OpenStreetMapSpace}) =
    Tuple(model.space.map.node_coordinates[pos])
latlon(pos::Tuple{Int,Int,Float64}, model::ABM{<:OpenStreetMapSpace}) =
    reverse(lonlat(pos, model))
latlon(agent::A, model::ABM{<:OpenStreetMapSpace,A}) where {A<:AbstractAgent} =
    latlon(agent.pos, model)

"""
    OSM.nearest_node(lonlat::Tuple{Float64,Float64}, model::ABM{<:OpenStreetMapSpace})

Return the nearest intersection position to **(longitude, latitude)**.
Quicker, but less precise than [`OSM.nearest_road`](@ref).
"""
function nearest_node(ll::Tuple{Float64,Float64}, model::ABM{<:OpenStreetMapSpace})
    ll = reverse(ll)
    nearest_node_id = LightOSM.nearest_node(model.space.map,
        [GeoLocation(ll..., 0.0)])[1][1][1]
    vert = Int(model.space.map.node_to_index[nearest_node_id])
    return (vert, vert, 0.0)
end

"""
    OSM.nearest_road(lonlat::Tuple{Float64,Float64}, model::ABM{<:OpenStreetMapSpace})

Return a location on a road nearest to **(longitude, latitude)**.
Significantly slower, but more precise than [`OSM.nearest_node`](@ref).
"""
function nearest_road(ll::Tuple{Float64,Float64}, model::ABM{<:OpenStreetMapSpace})
    ll = reverse(ll)
    best_sq_dist = Inf
    best = (-1, -1, -1.0)
    pt = LightOSM.to_cartesian(GeoLocation(ll..., 0.0))
    for e in edges(model.space.map.graph)
        s = LightOSM.to_cartesian(GeoLocation(
            model.space.map.node_coordinates[src(e)]..., 0.0))
        d = LightOSM.to_cartesian(GeoLocation(
            model.space.map.node_coordinates[dst(e)]..., 0.0))
        road_vec = d .- s

        # closest point on line segment requires checking if perpendicular
        # from point lies on line segment. If not, use the closest end of the line segment
        if dot(pt .- s, road_vec) < 0.0
            int_pt = s
        elseif dot(pt .- d, road_vec) > 0.0
            int_pt = d
        else
            int_pt = s .+ (dot(pt .- s, road_vec) / dot(road_vec, road_vec)) .* road_vec
        end

        sq_dist = dot(int_pt .- pt, int_pt .- pt)

        if sq_dist < best_sq_dist
            best_sq_dist = sq_dist
            rd_dist = norm(int_pt .- s) / norm(road_vec) *
                      road_length(Int(src(e)), Int(dst(e)), model)

            best = (
                Int(src(e)),
                Int(dst(e)),
                rd_dist,
            )
        end
    end

    return best
end

"""
    OSM.road_length(start::Int, finish::Int, model)
    OSM.road_length(pos::Tuple{Int,Int,Float64}, model)

Return the road length between two intersections. This takes into account the
direction of the road, so `OSM.road_length(pos_1, pos_2, model)` may not be the
same as `OSM.road_length(pos_2, pos_1, mode)`. Units of the returned quantity
are as specified by the underlying graph's `weight_type`. If `start` and `finish`
are the same or `pos[1]` and `pos[2]` are the same, then return 0.
"""
road_length(pos::Tuple{Int,Int,Float64}, model::ABM{<:OpenStreetMapSpace}) =
    road_length(pos[1], pos[2], model)
function road_length(p1::Int, p2::Int, model::ABM{<:OpenStreetMapSpace})
    p1 == p2 && return 0.0

    len = model.space.map.weights[p1, p2]
    if len == 0.0 || len == Inf
        len = model.space.map.weights[p2, p1]
    end
    return len
end

function Agents.is_stationary(agent, model::ABM{<:OpenStreetMapSpace})
    return !haskey(model.space.routes, agent.id)
end

"""
    OSM.get_geoloc(pos::Int, model::ABM{<:OpenStreetMapSpace})

Return `GeoLocation` corresponding to node `pos`
"""
get_geoloc(pos::Int, model::ABM{<:OpenStreetMapSpace}) =
    GeoLocation(model.space.map.node_coordinates[pos]..., 0.0)

"""
    OSM.get_reverse_direction(pos::Tuple{Int,Int,Float64}, model::ABM{<:OpenStreetMapSpace})

Return the same position, but with `pos[1]` and `pos[2]` swapped and `pos[3]` updated.
"""
get_reverse_direction(pos::Tuple{Int,Int,Float64}, model::ABM{<:OpenStreetMapSpace}) =
    (pos[2], pos[1], road_length(pos, model) - pos[3])

"""
    OSM.same_position(a::Tuple{Int,Int,Float64}, b::Tuple{Int,Int,Float64}, model::ABM{<:OpenStreetMapSpace})

Return `true` if the given positions `a` and `b` are (approximately) identical
"""
same_position(a::Tuple{Int,Int,Float64}, b::Tuple{Int,Int,Float64}, model::ABM{<:OpenStreetMapSpace}) =
    _same_position_node(a, b, model) || _same_position_node(b, a, model) ||
    _same_position_edge(a, b, model) || _same_position_internal(a, b, model)

# Handles the case when `a` is a node
function _same_position_node(
    a::Tuple{Int,Int,Float64},
    b::Tuple{Int,Int,Float64},
    model::ABM{<:OpenStreetMapSpace}
)
    a[1] != a[2] && return false    # this case handles when `a` is a node
    if a[1] == b[1] == b[2] # b is also an intersection point
        return true
    elseif a[1] == b[1] && b[3] ≈ 0.0 # the source vertex of edge `b` is `a` and position is nearby
        return true
    elseif a[1] == b[2] && b[3] ≈ road_length(b, model) # destination vertex is `a` and position nearby
        return true
    end
    return false
end

# Handles the case when both points are on edges with a common node, and close to that end of the edge
function _same_position_edge(
    a::Tuple{Int,Int,Float64},
    b::Tuple{Int,Int,Float64},
    model::ABM{<:OpenStreetMapSpace},
)
    # common node could be either end of either edge, so 4 cases total + the checks to ensure the position
    # along the edge (index 3) is also at that end

    if a[3] ≈ 0.0 # point `a` is near source node
        if a[1] == b[1] && b[3] ≈ 0.0 # source vertex of `b` is same and it is near that end
            return true
        elseif a[1] == b[2] && b[3] ≈ road_length(b, model) # destination vertex of `b` is same
            return true
        end
    elseif a[3] ≈ road_length(a, model)
        if a[2] == b[1] && b[3] ≈ 0.0 # source vertex of `b` is same
            return true
        elseif a[2] == b[2] && b[3] ≈ road_length(b, model) # destination vertex of `b` is same
            return true
        end
    end
    # either there is no common vertex or either one is not near the common vertex
    return false
end

# Handles case when both points are on the same edge (facing either direction)
_same_position_internal(
    a::Tuple{Int,Int,Float64},
    b::Tuple{Int,Int,Float64},
    model::ABM{<:OpenStreetMapSpace},
) =
    (a[1] == b[1] && a[2] == b[2] && a[3] ≈ b[3]) ||    # facing same direction
    (a[1] == b[2] && a[2] == b[1] && a[3] ≈ road_length(a, model) - b[3])   # facing opposite direction

"""
    OSM.same_road(a::Tuple{Int,Int,Float64}, b::Tuple{Int,Int,Float64})

Return `true` if both points lie on the same road of the graph
"""
same_road(
    a::Tuple{Int,Int,Float64},
    b::Tuple{Int,Int,Float64},
) = (a[1] == b[1] && a[2] == b[2]) || (a[1] == b[2] && a[2] == b[1])

"""
    OSM.closest_node_on_edge(a::Tuple{Int,Int,Float64}, model::ABM{<:OpenStreetMapSpace})

Return the node that the given point is closest to on its edge
"""
function closest_node_on_edge(a::Tuple{Int,Int,Float64}, model::ABM{<:OpenStreetMapSpace})
    if a[1] == a[2] || 2.0 * a[3] < road_length(a, model)
        return a[1]
    else
        return a[2]
    end
end
#######################################################################################
# Agents.jl space API
#######################################################################################
function Agents.random_position(model::ABM{<:OpenStreetMapSpace})
    vert = Int(rand(model.rng, 1:Agents.nv(model)))
    return (vert, vert, 0.0)
end

function Agents.add_agent_to_space!(
    agent::A,
    model::ABM{<:OpenStreetMapSpace,A},
) where {A<:AbstractAgent}
    push!(model.space.s[agent.pos[1]], agent.id)
    return agent
end

function Agents.remove_agent_from_space!(
    agent::A,
    model::ABM{<:OpenStreetMapSpace,A},
) where {A<:AbstractAgent}
    prev = model.space.s[agent.pos[1]]
    ai = findfirst(i -> i == agent.id, prev)
    deleteat!(prev, ai)
    return agent
end

function Agents.move_agent!(
    agent::A,
    pos::Tuple{Int,Int,Float64},
    model::ABM{<:OpenStreetMapSpace,A},
) where {A<:AbstractAgent}
    if pos[1] == agent.pos[1]
        agent.pos = pos
        return agent
    end
    Agents.remove_agent_from_space!(agent, model)
    agent.pos = pos
    Agents.add_agent_to_space!(agent, model)
end

"""
    move_along_route!(agent, model::ABM{<:OpenStreetMapSpace}, distance::Real) → remaining

Move an agent by `distance` along its planned route. Units of distance are as specified
by the underlying graph's weight_type. If the provided `distance` is greater than the
distance to the end of the route, return the remaining distance. Otherwise, return `0`.
`0` is also returned if `is_stationary(agent, model)`.
"""
function Agents.move_along_route!(
    agent::A,
    model::ABM{<:OpenStreetMapSpace,A},
    distance::Real,
) where {A<:AbstractAgent}
    if is_stationary(agent, model) || distance == 0
        return 0.0
    end

    # branching here corresponds to nesting of the following cases:
    # - Is the agent moving to the end of the road or somewhere in the middle (isempty(osmpath.route))
    # - Is `distance` more than the distance to the next waypoint / end of route (will it overshoot)?
    #   - Did we reach the end of the route? If so, does the agent need to return?
    #     - If the agent returns, what direction does it go in?
    #   - If we have another waypoint after this, move there
    # It might be easier to formulate this as a recursive structure, so recursive calls are annotated where necessary
    # instead of the loop this currently runs in. These annotations are marked with `##` just to make it clear.

    osmpath = model.space.routes[agent.id]
    while distance > 0.0
        # check if reached end
        if same_position(agent.pos, osmpath.dest, model)
            if osmpath.has_to_return
                if agent.pos[1] == agent.pos[2]
                    osmpath.return_route[end] == agent.pos[1] && pop!(osmpath.return_route)

                    move_agent!(agent, (agent.pos[1], osmpath.return_route[end], 0.0), model)
                elseif osmpath.return_route[end] == agent.pos[1]
                    move_agent!(agent, get_reverse_direction(agent.pos, model), model)
                end
                osmpath = model.space.routes[agent.id] = OpenStreetMapPath(
                    osmpath.return_route,
                    agent.pos,
                    osmpath.start,
                    Int[],
                    false,
                )
                continue
            end

            delete!(model.space.routes, agent.id)
            break
        end

        if isempty(osmpath.route) # last leg
            distance_to_end = if osmpath.dest[1] == agent.pos[1]
                osmpath.dest[3] - agent.pos[3]
            else
                road_length(osmpath.dest, model) - osmpath.dest[3] - agent.pos[3]
            end
            if distance_to_end <= distance
                distance -= distance_to_end
                move_agent!(agent, osmpath.dest, model)
                continue
            end

            move_agent!(agent, (agent.pos[1], agent.pos[2], agent.pos[3] + distance), model)
            distance = 0.0
        else
            distance_to_next_waypoint = road_length(agent.pos, model) - agent.pos[3]
            if distance_to_next_waypoint <= distance
                distance -= distance_to_next_waypoint
                a = pop!(osmpath.route)
                
                if isempty(osmpath.route)
                    if osmpath.dest[1] == agent.pos[2]
                        move_agent!(agent, (osmpath.dest[1], osmpath.dest[2], 0.0), model)
                    else
                        move_agent!(agent, (osmpath.dest[2], osmpath.dest[1], 0.0), model)
                    end
                    continue
                end

                b = osmpath.route[end]
                move_agent!(agent, (a, b, 0.0), model)
            else
                move_agent!(agent, (agent.pos[1], agent.pos[2], agent.pos[3] + distance), model)
                distance = 0.0
            end
        end
    end

    return distance
end

# Nearby positions must be intersections, since edges imply a direction.
# nearby agents/ids can be on an intersection or on a road X m away.
# We cannot simply use nearby_positions to collect nearby ids then.

# Default is searching both backwards and forwards.
# I assume it would be useful to turn off one or the other at some point.
function Agents.nearby_ids(
    pos::Tuple{Int,Int,Float64},
    model::ABM{<:OpenStreetMapSpace},
    distance::Real,
    args...;
    kwargs...
)
    distances = Dict{Int,Float64}()
    queue = Queue{Int}()
    nearby = Int[]

    if pos[1] == pos[2]
        distances[pos[1]] = 0.0
        enqueue!(queue, pos[1])
    else
        dist_1 = pos[3]
        dist_2 = road_length(pos, model) - pos[3]

        if dist_1 <= distance && dist_2 <= distance
            # just add to queue, all IDs on this road will be covered
            distances[pos[1]] = dist_1
            enqueue!(queue, pos[1])
            distances[pos[2]] = dist_2
            enqueue!(queue, pos[2])
        elseif dist_1 <= distance   # && dist_2 > distance
            # BFS covers IDs `distance` away from `pos[1]`, but not those in range
            # `(distance, dist_1 + distance)` away
            distances[pos[2]] = dist_2
            enqueue!(queue, pos[2])
            # push IDs that won't be covered
            for id in forward_ids_on_road(pos[1], pos[2], model)
                dist_1 < model[id].pos[3] <= dist_1 + distance && push!(nearby, id)
            end
            for id in reverse_ids_on_road(pos[1], pos[2], model)
                dist = road_length(pos, model) - model[id].pos[3]
                dist_1 < dist <= dist_1 + distance && push!(nearby, id)
            end
        elseif dist_2 <= distance # && dist_1 > distance
            # BFS covers IDs `distance` away from `pos[2]`, but not those in range
            # `(distance, dist_2 + distance)` away
            distances[pos[2]] = dist_2
            enqueue!(queue, pos[2])
            # push IDs that won't be covered
            for id in forward_ids_on_road(pos[1], pos[2], model)
                dist = road_length(pos, model) - model[id].pos[3]
                dist_2 < dist <= dist_2 + distance && push!(nearby, id)
            end
            for id in reverse_ids_on_road(pos[1], pos[2], model)
                dist_2 < model[id].pos[3] < dist_2 + distance && push!(nearby, id)
            end
        else # neither node is within `distance` of `pos`, so simply filter IDs on this road
            for id in forward_ids_on_road(pos[1], pos[2], model)
                abs(model[id].pos[3] - dist_1) <= distance && push!(nearby, id)
            end
            for id in reverse_ids_on_road(pos[1], pos[2], model)
                abs(model[id].pos[3] - dist_2) <= distance && push!(nearby, id)
            end
        end
    end

    # NOTE: During BFS, each node is only explored once.
    # From each node, every outgoing and incoming edge is considered and the node on the
    # other end is added to the queue if it is close enough. The edge is explored
    # for IDs by the node with the lower index (to prevent the same edge from being
    # explored twice). If the node on the other end can't be reached, then the current
    # node explores however far it can on this road. If the other node is reached through
    # another path, it takes this into account and only explores
    # the unexplored part of this edge.
    while !isempty(queue)
        node = dequeue!(queue)
        for nb in nearby_positions(node, model; neighbor_type = :all)
            rd_len = road_length(node, nb, model)
            if rd_len == 0.0 || rd_len == Inf
                rd_len = road_length(nb, node, model)
            end

            if rd_len <= distance - distances[node]  # can reach pos_2 from this node
                if !haskey(distances, nb) # mark for exploration if not visited
                    distances[nb] = distances[node] + rd_len
                    enqueue!(queue, nb)
                end
                if node < nb # road is explored by smaller indexed node
                    append!(nearby, ids_on_road(node, nb, model))
                end
            else
                # cannot reach pos_2 from this node
                dist_to_explore = distance - distances[node]
                if haskey(distances, nb)
                    # part of it is already explored, so only explore remaining part
                    dist_to_explore = max(min(dist_to_explore, rd_len - distances[nb]), 0.0)
                end
                for id in forward_ids_on_road(node, nb, model)
                    model[id].pos[3] <= dist_to_explore && push!(nearby, id)
                end
                for id in reverse_ids_on_road(node, nb, model)
                    dist = rd_len - model[id].pos[3]
                    dist <= dist_to_explore && push!(nearby, id)
                end
            end
        end
    end

    return nearby
end

forward_ids_on_road(pos_1::Int, pos_2::Int, model::ABM{<:OpenStreetMapSpace}) =
    Iterators.filter(i -> model[i].pos[2] == pos_2, model.space.s[pos_1])

reverse_ids_on_road(pos_1::Int, pos_2::Int, model::ABM{<:OpenStreetMapSpace}) =
    forward_ids_on_road(pos_2, pos_1, model)

ids_on_road(pos_1::Int, pos_2::Int, model::ABM{<:OpenStreetMapSpace}) =
    Iterators.flatten((
        forward_ids_on_road(pos_1, pos_2, model),
        reverse_ids_on_road(pos_1, pos_2, model),
    ))

function Agents.nearby_ids(
    agent::A,
    model::ABM{<:OpenStreetMapSpace,A},
    args...;
    kwargs...
) where {A<:AbstractAgent}
    all = nearby_ids(agent.pos, model, args...; kwargs...)
    filter!(i -> i ≠ agent.id, all)
end

Agents.nearby_positions(pos::Tuple{Int,Int,Float64}, model, args...; kwargs...) =
    nearby_positions(pos[1], model, args...; kwargs...)

function Agents.nearby_positions(
    position::Int,
    model::ABM{<:OpenStreetMapSpace};
    neighbor_type::Symbol = :default
)
    @assert neighbor_type ∈ (:default, :all, :in, :out)
    neighborfn = if neighbor_type == :default
        Graphs.neighbors
    elseif neighbor_type == :in
        Graphs.inneighbors
    elseif neighbor_type == :out
        Graphs.outneighbors
    else
        Graphs.all_neighbors
    end
    Int.(neighborfn(model.space.map.graph, position))
end

# Deprecations
function latlon(args...)
    @warn "`latlon` is deprecated in favor of `lonlat`."
    return reverse(lonlat(args...))
end

@deprecate random_route! plan_random_route!
@deprecate intersection nearest_node
@deprecate road nearest_road

end # module OSM

const OpenStreetMapSpace = OSM.OpenStreetMapSpace

const OSMSpace = OSM.OpenStreetMapSpace

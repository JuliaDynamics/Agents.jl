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
using LinearAlgebra: cross, dot, norm

export TEST_MAP,
    random_road_position,
    plan_route!,
    map_coordinates,
    road_length,
    random_route!,
    latlon,
    intersection,
    road

struct OpenStreetMapPath
    route::Vector{Int}
    start::Tuple{Int,Int,Float64}
    dest::Tuple{Int,Int,Float64}
    return_route::Vector{Int}
    current_target::Int
end

# NOTE: All positions are indexed by node id and _not_ vertex number
struct OpenStreetMapSpace <: Agents.DiscreteSpace # TODO: Why is this a discrete space?
    m::OSMGraph
    s::Vector{Vector{Int}}
    routes::Dict{Int,OpenStreetMapPath}
end

function OpenStreetMapSpace(
    path::AbstractString;
)
    m = get_map_data(path)
    agent_positions = [Int[] for i = 1:Agents.nv(m.graph)]
    return OpenStreetMapSpace(m, agent_positions, Dict())
end

function Base.show(io::IO, s::OpenStreetMapSpace)
    print(
        io,
        "OpenStreetMapSpace with $(length(s.m.highways)) roadways " *
        "and $(length(s.m.nodes)) intersections",
    )
end

#const TEST_MAP =
#    joinpath(dirname(pathof(OpenStreetMapX)), "..", "test", "data", "reno_east3.osm")

#######################################################################################
# Custom functions for OSMSpace
#######################################################################################

# EXPORTED
"""
    OSM.random_road_position(model::ABM{OpenStreetMapSpace})

Similar to [`random_position`](@ref), but rather than providing only intersections, this method
returns a location somewhere on a road heading in a random direction.
"""
function random_road_position(model::ABM{<:OpenStreetMapSpace})
    # pick a random source and destination, and then a random distance on that edge
    s = rand(model.rng, 1:Agents.nv(model))
    d = rand(model.rng, outneighbors(model.space.m.graph, s))
    dist = rand(model.rng)
    return (model.space.m.index_to_node(s), model.space.m.index_to_node(d), dist)
end

"""
    OSM.random_route!(agent, model::ABM{<:OpenStreetMapSpace})

Plan a new random route for the agent, by selecting a random destination and
planning a route from the agent's current position. Overwrite any current route.
"""
function random_route!(
    agent::A,
    model::ABM{<:OpenStreetMapSpace,A};
    return_trip = false,
    kwargs...
) where {A<:AbstractAgent}
    plan_route!(agent, random_road_position(model), model; return_trip, kwargs...)
end

"""
    OSM.plan_route(start, finish, model::ABM{<:OpenStreetMapSpace};
                   by = :shortest, return_trip = false, kwargs...)

Generate a list of intersections between `start` and `finish` points on the map.
`start` and `finish` can either be intersections (`Int`) or positions
(`Tuple{Int,Int,Float64}`).

When either point is a position, the associated intersection index will be removed from
the route to avoid double counting.

If `return_trip = true`, a route will be planned from start -> finish -> start.
"""
function plan_route!(
    agent::A,
    dest::Tuple{Int,Int,Float64},
    model::ABM{<:OpenStreetMapSpace,A};
    return_trip = false,
    kwargs...
) where {A<:AbstractAgent}
    # get route to destination
    route = shortest_path(
        model.space.m,
        agent.pos[2],
        dest[1];
        kwargs...
    )
    # reverse, so we can pop nodes off the end as they are visited
    reverse!(route)
    # get return route
    return_route = if return_trip
        shortest_path(
            model.space.m,
            dest[1],
            agent.pos[2];
            kwargs...
        )
    else
        Int[]
    end
    reverse!(return_route)
    model.space.routes[agent.id] = OpenStreetMapPath(
        route,
        agent.pos,
        dest,
        return_route,
        length(route)
    )
    return nothing
end

# Allos passing destination as an index
plan_route!(agent::A, dest::Int, model; kwargs...) where {A<:AbstractAgent} =
    plan_route!(a, (dest, dest, 0.0), model; kwargs...)

"""
    OSM.latlon(pos, model)
    OSM.latlon(agent, model)

Return (latitude, longitude) of current road or intersection position.
"""
function latlon(pos::Int, model::ABM{<:OpenStreetMapSpace})
    loc = model.space.m.nodes[pos].location
    return (loc.lat, loc.lon)
end

function latlon(pos::Tuple{Int,Int,Float64}, model::ABM{<:OpenStreetMapSpace})
    if pos[1] != pos[2]
        dir = heading(pos[1], pos[2])
        dist = pos[3] * road_length(pos, model)
        geoloc = calculate_location(pos[1], dir, dist)
        return (geoloc.lat, geoloc.lon)
    else
        return OpenStreetMapX.latlon(model.space.m, pos[1])
    end
end

latlon(agent::A, model::ABM{<:OpenStreetMapSpace,A}) where {A<:AbstractAgent} =
    latlon(agent.pos, model)

"""
    intersection(latlon::Tuple{Float64,Float64}, model::ABM{<:OpenStreetMapSpace})

Return the nearest intersection position to (latitude, longitude).
Quicker, but less precise than [`OSM.road`](@ref).
"""
function intersection(ll::Tuple{Float64,Float64}, model::ABM{<:OpenStreetMapSpace})
    node = nearest_node(model.space.m, [GeoLocation(ll..., 0.0)])[1][1][1]
    return (node, node, 0.0)
end

"""
    OSM.road(latlon::Tuple{Float64,Float64}, model::ABM{<:OpenStreetMapSpace})

Return a location on a road nearest to (latitude, longitude).
Slower, but more precise than [`OSM.intersection`](@ref).
"""
function road(ll::Tuple{Float64,Float64}, model::ABM{<:OpenStreetMapSpace})
    best_dist = Inf
    best = (-1, -1, -1.0)
    for e in edges(model.space.m.graph)
        s = model.space.m.node_coordinates[src(e)]
        d = model.space.m.node_coordinates[dst(d)]
        dist = point_to_geodesic_line_dist(ll, s, d)
        if dist < best_dist
            best_dist = dist
            best = (
                model.space.m.index_to_node[src(e)],
                model.space.m.index_to_node[dst(e)],)
            # TODO:
        end
    end
end


# distance between pt and geodesic line joining points p and q on a unit sphere
# see: https://math.stackexchange.com/a/23612
function point_to_geodesic_line_dist(pt, p, q)
    x = to_cartesian(pt[1], pt[2], 1.0)
    a = to_cartesian(p[1], p[2], 1.0)
    b = to_cartesian(q[1], q[2], 1.0)
    vec = cross(a, b)
    vec = vec ./ norm(vec)
    return asin(abs(dot(vec, x)))
end

"""
    OSM.map_coordinates(agent, model::ABM{OpenStreetMapSpace})

Return a set of coordinates for an agent on the underlying map. Useful for plotting.
"""
function map_coordinates(agent, model)
    if agent.pos[1] != agent.pos[2]
        start = get_EastNorthUp_coordinate(agent.pos[1], model)
        finish = get_EastNorthUp_coordinate(agent.pos[2], model)
        travelled = agent.pos[3] / road_length(agent.pos, model)
        (
            getX(start) * (1 - travelled) + getX(finish) * travelled,
            getY(start) * (1 - travelled) + getY(finish) * travelled,
        )
    else
        position = get_EastNorthUp_coordinate(agent.pos[1], model)
        (getX(position), getY(position))
    end
end

"""
    OSM.road_length(start::Int, finish::Int, model)
    OSM.road_length(pos::Tuple{Int,Int,Float64}, model)

Return the road length (in meters) between two intersections given by intersection ids.
"""
road_length(pos::Tuple{Int,Int,Float64}, model::ABM{<:OpenStreetMapSpace}) =
    road_length(pos[1], pos[2], model)
road_length(p1::Int, p2::Int, model::ABM{<:OpenStreetMapSpace}) = model.space.m.weights[p1, p2]

function Agents.is_stationary(agent, model::ABM{<:OpenStreetMapSpace})
    return agent.pos == agent.destination && isempty(agent.route)
end

# HELPERS, NOT EXPORTED
function random_point_in_bounds(model::ABM{<:OpenStreetMapSpace})
    bounds = model.space.m.kdtree.hyper_rec
    return (
        rand(model.rng) * (bounds.max[1] - bounds.min[1]) + bounds.min[1],
        rand(model.rng) * (bounds.max[2] - bounds.min[2]) + bounds.min[2],
    )
end

"""
    get_EastNorthUp_coordinate(pos::Int, model)

Return an East-North-Up coordinate value for index `pos`.
"""
get_EastNorthUp_coordinate(pos::Int, model) = model.space.m.nodes[model.space.m.n[pos]]

#######################################################################################
# Agents.jl space API
#######################################################################################

function Agents.random_position(model::ABM{<:OpenStreetMapSpace})
    ll = random_point_in_bounds(model)
    return intersection(ll, model)
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

function move_agent!(
    agent::A,
    pos::Tuple{Int,Int,Float64},
    model::ABM{<:OpenStreetMapSpace,A},
) where {A}
    Agents.remove_agent_from_space!(agent, model)
    agent.pos = pos
    Agents.add_agent_to_space!(agent, model)
end

"""
    move_along_route!(agent, model::ABM{<:OpenStreetMapSpace}, distance::Real)

Move an agent by `distance` in meters along its planned route.
"""
function Agents.move_along_route!(
    agent::A,
    model::ABM{<:OpenStreetMapSpace,A},
    distance::Real,
) where {A<:AbstractAgent}

    if is_stationary(agent, model)
        return nothing
    end

    dist_to_intersection = road_length(agent.pos, model) - agent.pos[3]

    if isempty(agent.route) && agent.pos[1:2] == agent.destination[1:2]
        # Last one or two moves before destination
        to_travel = agent.destination[3] - agent.pos[3]
        if distance >= to_travel
            pos = agent.destination
        else
            pos = (agent.destination[1:2]..., agent.pos[3] + distance)
        end
    elseif distance >= dist_to_intersection
        if !isempty(agent.route)
            pos = travel!(
                agent.pos[2],
                popfirst!(agent.route),
                distance - dist_to_intersection,
                agent,
                model,
            )
        else
            # Now moving to the final destination
            pos = park(distance - dist_to_intersection, agent, model)
        end
    else
        # move up current path
        pos = (agent.pos[1], agent.pos[2], agent.pos[3] + distance)
    end

    move_agent!(agent, pos, model)
end

function travel!(start, finish, distance, agent, model)
    # Assumes we have just reached the intersection of `start` and `finish`,
    # and have `distance` left to travel.
    edge_distance = road_length(start, finish, model)
    if edge_distance <= distance
        if !isempty(agent.route)
            return travel!(
                finish,
                popfirst!(agent.route),
                distance - edge_distance,
                agent,
                model,
            )
        else
            #######################################
            # TODO: The code here can be simplified by using the existing `park`.
            # alright, so here we're in a situation where the agent is imagined to be at
            # 'start' with 'distance left to travel.
            # the route is empty, but (start,finish) does not equal agent.destination[1:2]
            # what follows is the srouce code of the function "park", but the 'virtual'
            # agent in it has position
            # pos=(start,finish,distance-edge_distance)
            # so I replaced that and nothing else.
            distance -= edge_distance
            if finish != agent.destination[1]
                # At the end of the route, we must travel
                last_distance = road_length(finish, agent.destination[1], model)
                if distance >= last_distance + agent.destination[3]
                    # We reach the destination
                    return agent.destination
                elseif distance >= last_distance
                    # We reach the final road, but not the destination
                    return (agent.destination[1:2]..., distance - last_distance)
                else
                    # We travel the final leg
                    return (finish, agent.destination[1], distance)
                end
            else
                # Reached final road
                if distance >= agent.destination[3]
                    return agent.destination
                else
                    return (agent.destination[1:2]..., distance)
                end
            end
            #######################################
        end
    else
        return (start, finish, distance)
    end
end

function park(distance, agent, model)
    # We have no route left but have not quite yet arrived at our destination.
    # Assumes that when this is called, we have just completed the current leg
    # in `agent.pos`, and we have `distance` left to travel.
    if agent.pos[2] != agent.destination[1]
        # At the end of the route, we must travel
        last_distance = road_length(agent.pos[2], agent.destination[1], model)
        if distance >= last_distance + agent.destination[3]
            # We reach the destination
            return agent.destination
        elseif distance >= last_distance
            # We reach the final road, but not the destination
            return (agent.destination[1:2]..., distance - last_distance)
        else
            # We travel the final leg
            return (agent.pos[2], agent.destination[1], distance)
        end
    else
        # Reached final road
        if distance >= agent.destination[3]
            return agent.destination
        else
            return (agent.destination[1:2]..., distance)
        end
    end
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
    current_road = road_length(pos, model)
    nearby = Int[]

    close = ids_on_road(pos[1], pos[2], model)
    pos_search = pos[3] + distance
    if distance > current_road - pos[3]
        # Local search distance
        pos_search = current_road

        # Check outgoing
        search_distance = distance - (current_road - pos[3])
        search_outward_ids!(nearby, search_distance, pos[1], pos[2], model)
    end
    # Check anyone close in the forward direction
    if !isempty(close)
        for (id, dist) in close
            if pos[3] <= dist <= pos_search
                push!(nearby, id)
            end
        end
    end
    rev_search = pos[3] - distance
    if rev_search < 0
        # Local search distance
        rev_search = 0.0

        # Check incoming
        search_distance = distance - pos[3]
        search_inward_ids!(nearby, search_distance, pos[1], pos[2], model)
    end
    # Check anyone close in the reverse direction
    if !isempty(close)
        for (id, dist) in close
            if rev_search <= dist <= pos[3]
                push!(nearby, id)
            end
        end
    end
    return nearby
end

function ids_on_road(
    pos1::Int,
    pos2::Int,
    model::ABM{<:OpenStreetMapSpace},
    reverse = false,
)
    distance = road_length(pos1, pos2, model)
    dist_front(d) = reverse ? distance - d : d
    dist_back(d) = reverse ? d : distance - d
    # Agents listed in the current position, filtered to current road
    # (id, distance)
    res = [
        (model[i].id, dist_front(model[i].pos[3]))
        for i in model.space.s[pos1] if model[i].pos[2] == pos2
    ]
    # Opposite direction. We must invert the distances here to obtain a relative
    # distance from `pos`
    # NOTE: I think a complication happens here when we're looking at divided roads.
    # They don't end up having
    # the same ids, so this comparison isn't possible. Unsure if we can do something
    # about that using OpenStreetMapX or not.
    append!(
        res,
        [
            (model[i].id, dist_back(model[i].pos[3]))
            for i in model.space.s[pos2] if model[i].pos[2] == pos1
        ],
    )
    res
end

function search_outward_ids!(
    nearby::Vector{Int},
    distance::Real,
    pos1::Int,
    pos2::Int,
    model,
)
    # find all intersections the current end position connects to
    outgoing = filter(i -> i != pos1, nearby_positions(pos2, model; neighbor_type = :out))
    # Distances for each road
    outdist = [road_length(pos2, o, model) for o in outgoing]
    # Identify roads that are shorter than the search distance
    go_deeper = findall(i -> i < distance, outdist)
    # Those in the `go_deeper` category are completely covered by the distance search.
    # Any agent found in the heading or opposite directions along this road are counted.
    for i in go_deeper
        finish = outgoing[i]
        for (id, _) in ids_on_road(pos2, finish, model)
            push!(nearby, id)
        end
        # We must recursively look up branches until the search distance is met
        search_outward_ids!(nearby, distance - outdist[i], pos2, finish, model)
    end
    # Those not in the `go_deeper` category are searched in the positive direction
    setdiff!(outgoing, outgoing[go_deeper])
    to_collect = map(i -> ids_on_road(pos2, i, model), outgoing)
    filter!(!isempty, to_collect)
    if !isempty(to_collect)
        for (id, dist) in vcat(to_collect...)
            if dist <= distance
                push!(nearby, id)
            end
        end
    end
end

function search_inward_ids!(
    nearby::Vector{Int},
    distance::Real,
    pos1::Int,
    pos2::Int,
    model,
)
    # find all intersections the current start position connects to
    incoming = filter(i -> i != pos2, nearby_positions(pos1, model; neighbor_type = :in))
    # Distances for each road
    indist = [road_length(i, pos1, model) for i in incoming]
    # Identify roads that are shorter than the search distance
    go_deeper = findall(i -> i < distance, indist)
    # Those in the `go_deeper` category are completely covered by the distance search.
    # Any agent found in the heading or opposite directions along this road are counted.
    for i in go_deeper
        start = incoming[i]
        for (id, _) in ids_on_road(start, pos1, model)
            push!(nearby, id)
        end
        # We must recursively look up branches until the search distance is met
        search_inward_ids!(nearby, distance - indist[i], start, pos1, model)
    end
    # Those not in the `go_deeper` category are searched in the positive direction
    setdiff!(incoming, incoming[go_deeper])
    to_collect = map(i -> ids_on_road(i, pos1, model, true), incoming)
    filter!(!isempty, to_collect)
    if !isempty(to_collect)
        for (id, dist) in vcat(to_collect...)
            if dist <= distance
                push!(nearby, id)
            end
        end
    end
end

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
    neighborfn(model.space.m.g, position)
end

end # module OSM

"""
    OpenStreetMapSpace(path::AbstractString; kwargs...)
Create a space residing on the Open Street Map (OSM) file provided via `path`.
The functionality related to Open Street Map spaces is in the submodule `OSM`.

This space represents the underlying map as a *continuous* entity choosing accuracy over
performance by explicitly taking into account that every intersection is connected by
a road with a finite length in meters.
An example of its usage can be found in [Zombie Outbreak](@ref).
Nevertheless, all functions that target `DiscreteSpace`s apply here as well, e.g.
[`positions`](@ref). The discrete part are the underlying road intersections, that
are represented by a graph.

Much of the functionality of this space is provided by interfacing with
[OpenStreetMapX.jl](https://github.com/pszufe/OpenStreetMapX.jl), for example the two
keyword arguments `use_cache = false` and `trim_to_connected_graph = true` can be
passed into the `OpenStreetMapX.get_map_data` function.

For details on how to obtain an OSM file for your use case, consult the OpenStreetMapX.jl
README. We provide a variable `OSM.TEST_MAP` to use as a `path` for testing.

If your solution can tolerate routes to and from intersections only without caring for the
continuity of the roads in between, a faster implementation can be achieved by using the
[graph representation](https://pszufe.github.io/OpenStreetMapX.jl/stable/reference/#OpenStreetMapX.MapData)
of your map provided by OpenStreetMapX.jl. For tips on how to implement this, see our
integration example: [Social networks with Graphs.jl](@ref).

## The OSMAgent

The base properties for an agent residing on an `OSMSpace` are as follows:
```julia
mutable struct OSMAgent <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int,Float64}
    route::Vector{Int}
    destination::Tuple{Int,Int,Float64}
end
```

Current `pos`ition and `destination` tuples are represented as
`(start intersection index, finish intersection index, distance travelled in meters)`.
The `route` is an ordered list of intersections, providing a path to reach `destination`.

Further details can be found in [`OSMAgent`](@ref).

## Routing

There are two ways to generate a route, depending on the situation.
1. Assign the value of [`OSM.plan_route`](@ref) to the `.route` field of an Agent.
   This provides `:shortest` and `:fastest` paths (with the option of a `return_trip`)
   between intersections or positions.
2. [`OSM.random_route!`](@ref), choses a new `destination` an plans a new path to it;
   overriding the current route (if any).
"""
const OpenStreetMapSpace = OSM.OpenStreetMapSpace

const OSMSpace = OSM.OpenStreetMapSpace

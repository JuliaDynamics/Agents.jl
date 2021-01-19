export OpenStreetMapSpace, OSMSpace, TEST_MAP
export osm_random_road_position,
    osm_plan_route,
    osm_map_coordinates,
    osm_road_length,
    osm_is_stationary,
    osm_random_route!

struct OpenStreetMapSpace <: DiscreteSpace
    m::OpenStreetMapX.MapData
    edges::Vector{CartesianIndex{2}}
    s::Vector{Vector{Int}}
end

"""
    OpenStreetMapSpace(path::AbstractString; kwargs...)
Create a space residing on the Open Street Map (OSM) file provided via `path`.

The abbreviation `OSMSpace` may be used interchangeably.

Much of the functionality of this space is provided by interfacing with
[OpenStreetMapX.jl](https://github.com/pszufe/OpenStreetMapX.jl), for example the two
keyword arguments `use_cache = false` and `trim_to_connected_graph = true` can be
passed into the [`OpenStreetMapX.get_map_data`](@ref) function.

For details on how to obtain an OSM file for your use case, consult the OpenStreetMapX.jl
README. We provide a variable `TEST_MAP` to use as a `path` for testing.

This space represents the underlying map as a *continuous* entity choosing accuracy over
performance. An example of its usage can be found in [Zombie Outbreak](@ref).

If your solution can tolerate routes to and from intersections only, a
faster implementation can be achieved by using the
[graph representation](https://pszufe.github.io/OpenStreetMapX.jl/stable/reference/#OpenStreetMapX.MapData)
of your map provided by OpenStreetMapX.jl. For tips on how to implement this, see our
integration example: [Social networks with LightGraphs.jl](@ref).

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
1. [`osm_plan_route`](@ref), which provides `:shortest` and `:fastest` paths (with the option of a `return_trip`) between intersections or positions.
2. [`osm_random_route!`](@ref), choses a new `destination` an plans a new path to it; overriding the current route (if any).
"""
function OpenStreetMapSpace(
    path::AbstractString;
    use_cache = false,
    trim_to_connected_graph = true,
)
    m = get_map_data(path; use_cache, trim_to_connected_graph)
    agent_positions = [Int[] for i in 1:nv(m.g)]
    return OpenStreetMapSpace(m, findall(!iszero, m.w), agent_positions)
end

function Base.show(io::IO, s::OpenStreetMapSpace)
    print(
        io,
        "OpenStreetMapSpace with $(length(s.m.roadways)) roadways and $(length(s.m.intersections)) intersections",
    )
end

const OSMSpace = OpenStreetMapSpace

const TEST_MAP =
    joinpath(dirname(pathof(OpenStreetMapX)), "..", "test", "data", "reno_east3.osm")

#######################################################################################
# Custom functions for OSMSpace
#######################################################################################

# EXPORTED
"""
    osm_random_road_position(model::ABM{OpenStreetMapSpace})

Similar to `random_position`, but rather than providing only intersections, this method
returns a location somewhere on a road heading in a random direction.
"""
function osm_random_road_position(model::ABM{<:OpenStreetMapSpace})
    edge = rand(model.space.edges)
    return (edge.I..., rand() * model.space.m.w[edge])
end

"""
    osm_random_route!(agent, model::ABM{<:OpenStreetMapSpace})

Selects a random destination and plans a route from the agent's current position. Will
overwrite any current route.
"""
function osm_random_route!(agent, model::ABM{<:OpenStreetMapSpace})
    agent.destination = osm_random_road_position(model)
    agent.route = osm_plan_route(agent.pos, agent.destination, model)
    return nothing
end

"""
    osm_plan_route(start, finish, model::ABM{<:OpenStreetMapSpace};
                   by = :shortest, return_trip = false, kwargs...)

Generate a list of intersections between `start` and `finish` points on the map.
`start` and `finish` can either be intersections (`Int`) or positions
(`Tuple{Int,Int,Float64}`).

When either point is a position, the associated intersection index will be removed from
the route to avoid double counting.

Route is planned via the shortest path by default (`by = :shortest`), but can also be
planned `by = :fastest`. Road speeds are needed for this method which can be passed in via
extra keyword arguments. Consult the OpenStreetMapX documentation for more details.

If `return_trip = true`, a route will be planned from start -> finish -> start.
"""
function osm_plan_route(
    start::Int,
    finish::Int,
    model::ABM{<:OpenStreetMapSpace};
    by = :shortest,
    return_trip = false,
    kwargs...,
)
    @assert by ∈ (:shortest, :fastest) "Can only plan route by :shortest or :fastest"
    planner = by == :shortest ? shortest_route : fastest_route
    route = if return_trip
        planner(
            model.space.m,
            model.space.m.n[start],
            model.space.m.n[finish],
            model.space.m.n[start];
            kwargs...,
        )[1]
    else
        planner(model.space.m, model.space.m.n[start], model.space.m.n[finish]; kwargs...)[1]
    end
    map(p -> getindex(model.space.m.v, p), route)
end

function osm_plan_route(
    start::Tuple{Int,Int,Float64},
    finish::Int,
    model::ABM{<:OpenStreetMapSpace};
    return_trip = false,
    kwargs...,
)
    path = if return_trip
        plan_return_route(start[2], finish, start[1], model; kwargs...)
    else
        osm_plan_route(start[2], finish, model; kwargs...)
    end
    ## Since we start on an edge, there are two possibilities here.
    ## 1. The route wants us to turn around, thus next id en-route will
    ## be pos[1]. That's fine.
    ## 2. The route wants us to move on, but start will be in the list,
    ## so we need to drop that.
    if !isempty(path) && path[1] == start[2]
        popfirst!(path)
    end
    return path
end

function osm_plan_route(
    start,
    finish::Tuple{Int,Int,Float64},
    model::ABM{<:OpenStreetMapSpace};
    kwargs...,
)
    path = osm_plan_route(start, finish[1], model; kwargs...)
    isempty(path) || pop!(path)
    return path
end

function plan_return_route(
    start::Int,
    middle::Int,
    finish::Int,
    model::ABM{<:OpenStreetMapSpace};
    by = :shortest,
    kwargs...,
)
    planner = by == :shortest ? shortest_route : fastest_route
    route = planner(
        model.space.m,
        model.space.m.n[start],
        model.space.m.n[middle],
        model.space.m.n[finish];
        kwargs...,
    )[1]
    map(p -> getindex(model.space.m.v, p), route)
end

"""
    osm_map_coordinates(agent, model::ABM{OpenStreetMapSpace})

Return a set of coordinates for an agent on the underlying map. Useful for plotting.
"""
function osm_map_coordinates(agent, model)
    if agent.pos[1] != agent.pos[2]
        start = get_EastNorthUp_coordinate(agent.pos[1], model)
        finish = get_EastNorthUp_coordinate(agent.pos[2], model)
        travelled = agent.pos[3] / Agents.osm_road_length(agent.pos, model)
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
    osm_road_length(start::Int, finish::Int, model)
    osm_road_length(pos::Tuple{Int,Int,Float64}, model)

Return the road length (in meters) between two intersections given by intersection ids.
"""
osm_road_length(pos::Tuple{Int,Int,Float64}, model::ABM{<:OpenStreetMapSpace}) =
    osm_road_length(pos[1], pos[2], model)
osm_road_length(p1::Int, p2::Int, model::ABM{<:OpenStreetMapSpace}) =
    model.space.m.w[p1, p2]

"""
    osm_is_stationary(agent)

Return `true` if agent has no route left to follow and is therefore standing still.
"""
function osm_is_stationary(agent::A) where {A<:AbstractAgent}
    return agent.pos == agent.destination && isempty(agent.route)
end

#HELPERS, NOT EXPORTED

"""
    get_EastNorthUp_coordinate(pos::Int, model)

Return an East-North-Up coordinate value for index `pos`.
"""
get_EastNorthUp_coordinate(pos::Int, model) = model.space.m.nodes[model.space.m.n[pos]]

#######################################################################################
# Agents.jl space API
#######################################################################################

function random_position(model::ABM{<:OpenStreetMapSpace})
    intersection = rand(1:nv(model))
    return (intersection, intersection, 0.0)
end

function add_agent_to_space!(
    agent::A,
    model::ABM{<:OpenStreetMapSpace,A},
) where {A<:AbstractAgent}
    push!(model.space.s[agent.pos[1]], agent.id)
    return agent
end

function remove_agent_from_space!(
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
    remove_agent_from_space!(agent, model)
    agent.pos = pos
    add_agent_to_space!(agent, model)
end

"""
    move_agent!(agent, model::ABM{<:OpenStreetMapSpace}, distance::Real)

Move an agent by `distance` in meters along its planned route.
"""
function move_agent!(
    agent::A,
    model::ABM{<:OpenStreetMapSpace,A},
    distance::Real,
) where {A<:AbstractAgent}

    if osm_is_stationary(agent)
        return nothing
    end

    dist_to_intersection = osm_road_length(agent.pos, model) - agent.pos[3]

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
    edge_distance = osm_road_length(start, finish, model)
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
            return (finish, finish, 0.0)
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
        last_distance = osm_road_length(agent.pos[2], agent.destination[1], model)
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
function nearby_ids(
    pos::Tuple{Int,Int,Float64},
    model::ABM{<:OpenStreetMapSpace},
    distance::Real,
    args...;
    kwargs...,
)
    current_road = osm_road_length(pos, model)
    nearby = Int[]

    close = ids_on_road(pos[1], pos[2], model)
    if distance > current_road - pos[3]
        # Local search distance
        pos_search = current_road - pos[3]

        # Check outgoing
        search_distance = distance - pos_search
        search_outward_ids!(nearby, search_distance, pos[1], pos[2], model)
    else
        pos_search = pos[3] + distance
    end
    # Check anyone close in the forward direction
    if !isempty(close)
        for (id, dist) in close
            if pos[3] <= dist <= pos_search
                push!(nearby, id)
            end
        end
    end
    if pos[3] - distance < 0
        # Local search distance
        rev_search = pos[3]

        # Check incoming
        search_distance = distance - pos[3]
        search_inward_ids!(nearby, search_distance, pos[1], pos[2], model)
    else
        rev_search = pos[3] - distance
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
    distance = osm_road_length(pos1, pos2, model)
    dist_front(d) = reverse ? distance - d : d
    dist_back(d) = reverse ? d : distance - d
    # Agents listed in the current position, filtered to current road
    # (id, distance)
    res = [
        (model[i].id, dist_front(model[i].pos[3]))
        for i in model.space.s[pos1] if model[i].pos[2] == pos2
    ]
    # Opposite direction. We must invert the distances here to obtain a relative distance from `pos`
    #NOTE: I think a complication happens here when we're looking at divided roads. They don't end up having
    #the same ids, so this comparison isn't possible. Unsure if we can do something about that using
    #OpenStreetMapX or not.
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
    outgoing = filter(i -> i != pos1, nearby_positions(pos2, model))
    # Distances for each road
    outdist = [osm_road_length(pos2, o, model) for o in outgoing]
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
    indist = [osm_road_length(i, pos1, model) for i in incoming]
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

function nearby_ids(
    agent::A,
    model::ABM{<:OpenStreetMapSpace,A},
    args...;
    kwargs...,
) where {A<:AbstractAgent}
    all = nearby_ids(agent.pos, model, args...; kwargs...)
    filter!(i -> i ≠ agent.id, all)
end

nearby_positions(pos::Tuple{Int,Int,Float64}, model, args...; kwargs...) =
    nearby_positions(pos[1], model, args...; kwargs...)

function nearby_positions(
    position::Int,
    model::ABM{<:OpenStreetMapSpace};
    neighbor_type::Symbol = :default,
)
    @assert neighbor_type ∈ (:default, :all, :in, :out)
    neighborfn = if neighbor_type == :default
        LightGraphs.neighbors
    elseif neighbor_type == :in
        LightGraphs.inneighbors
    elseif neighbor_type == :out
        LightGraphs.outneighbors
    else
        LightGraphs.all_neighbors
    end
    neighborfn(model.space.m.g, position)
end

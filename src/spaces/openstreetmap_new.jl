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
using Pkg.Artifacts
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


# Stores information about an agent's path
struct OpenStreetMapPath
    route::Vector{Int}      # node IDs along path from `start` to `dest`
    start::Tuple{Int,Int,Float64} # Initial position of the agent
    dest::Tuple{Int,Int,Float64}    # Destination. `dest[1] == dest[2]` if this is an intersection
    return_route::Vector{Int}   # node IDs along path from `dest` to `start`
    has_to_return::Bool
end

# NOTE: All positions are indexed by node id and _not_ vertex number

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
struct OpenStreetMapSpace <: Agents.DiscreteSpace # TODO: Why is this a discrete space?
    map::OSMGraph
    s::Vector{Vector{Int}}
    routes::Dict{Int,OpenStreetMapPath} # maps agent ID to corresponding path
end

function OpenStreetMapSpace(
    path::AbstractString;
)
    m = graph_from_file(path)
    agent_positions = [Int[] for _ in 1:Agents.nv(m.graph)]
    return OpenStreetMapSpace(m, agent_positions, Dict())
end

function Base.show(io::IO, s::OpenStreetMapSpace)
    print(
        io,
        "OpenStreetMapSpace with $(length(s.map.highways)) roadways " *
        "and $(length(s.map.nodes)) intersections",
    )
end

function OSM_test_map()
    artifact_toml = joinpath(@__DIR__, "../../Artifacts.toml")
    map_hash = artifact_hash("osm_map_gottingen", artifact_toml)
    if isnothing(map_hash) || !artifact_exists(map_hash)
        map_hash = create_artifact() do artifact_dir
            download_osm_network(
                :place_name;
                save_to_file_location = joinpath(artifact_dir, "osm_map_gottingen.json"),
                place_name = "Gottingen"
            )
        end

        bind_artifact!(artifact_toml, "osm_map_gottingen", map_hash)
    end

    return joinpath(artifact_path(map_hash), "osm_map_gottingen.json")
end

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
    s = rand(model.rng, 1:Agents.nv(model))
    d = Int(rand(model.rng, outneighbors(model.space.map.graph, s)))
    s = model.space.map.index_to_node[s]
    d = model.space.map.index_to_node[d]
    dist = rand(model.rng) * road_length(s, d, model)
    return (s, d, dist)
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
    OSM.plan_route!(agent, dest, model::ABM{<:OpenStreetMapSpace};
                   return_trip = false, kwargs...)

Plan a route from the current position of `agent` to the location specified in `dest`, which
can be an intersection or a point on a road.

If `return_trip = true`, a route will be planned from start -> finish -> start. All other
keywords are passed to [`LightOSM.shortest_path`](https://deloittedigitalapac.github.io/LightOSM.jl/docs/shortest_path/#LightOSM.shortest_path)
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
        agent.pos[1],
        dest[1];
        kwargs...
    )
    if !isempty(route)
        # reverse, so we can pop nodes off the end as they are visited
        reverse!(route)
        if length(route) == 1 || route[end - 1] != agent.pos[2]   # need to go back to agent.pos[1], so reverse direction
            move_agent!(
                agent,
                (agent.pos[2], agent.pos[1], road_length(agent.pos, model) - agent.pos[3]),
                model
            )
        else
            pop!(route) # continue moving in this direction, so remove agent.pos[1] from path
        end
    end
    # get return route
    return_route = if return_trip
        shortest_path(
            model.space.m,
            dest[1],
            agent.pos[1];
            kwargs...
        )
    else
        Int[]
    end
    if !isempty(return_route)
        reverse!(return_route)
        if dest[1] == dest[2] ||  # starting from intersection, so don't add to path
            # return by continuing along same road, so remove initial point of road
            length(return_route) > 1 && dest[1] == return_route[end] && dest[2] == return_route[end - 1]
            pop!(return_route)
        end
    end
    model.space.routes[agent.id] = OpenStreetMapPath(
        route,
        agent.pos,
        dest,
        return_route,
        return_trip
    )
    return nothing
end

# Allows passing destination as an index
plan_route!(agent::A, dest::Int, model; kwargs...) where {A<:AbstractAgent} =
    plan_route!(a, (dest, dest, 0.0), model; kwargs...)

"""
    OSM.latlon(pos, model)
    OSM.latlon(agent, model)

Return `(latitude, longitude)` of current road or intersection position.
"""
latlon(pos::Int, model::ABM{<:OpenStreetMapSpace}) =
    (model.space.map.nodes[pos].location.lat, model.space.map.nodes[pos].location.lon)

function latlon(pos::Tuple{Int,Int,Float64}, model::ABM{<:OpenStreetMapSpace})
    if pos[1] != pos[2]
        gloc1 = get_geoloc(pos[1], model)
        gloc2 = get_geoloc(pos[2], model)
        dir = heading(gloc1, gloc2)
        geoloc = calculate_location(gloc1, dir, pos[3])
        return (geoloc.lat, geoloc.lon)
    else
        return latlon(pos[1], model)
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
    pt = LightOSM.to_cartesian(GeoLocation(ll..., 0.))
    for e in edges(model.space.map.graph)
        s = LightOSM.to_cartesian(GeoLocation(model.space.map.node_coordinates[src(e)]..., 0.))
        d = LightOSM.to_cartesian(GeoLocation(model.space.map.node_coordinates[dst(e)]..., 0.))
        road_vec = d .- s
        int_pt = s .+ (dot(pt .- s, road_vec) / dot(road_vec, road_vec)) .* road_vec
        sq_dist = dot(int_pt .- pt, int_pt .- pt)
        if sq_dist < best_dist
            best_dist = sq_dist
            rd_dist = norm(int_pt .- s)

            best = (
                model.space.map.index_to_node[src(e)],
                model.space.map.index_to_node[dst(e)],
                rd_dist,
            )
        end
    end

    return best
end

"""
    OSM.map_coordinates(agent, model::ABM{<:OpenStreetMapSpace})

Return a set of coordinates for an agent on the underlying map. Useful for plotting.
"""
function map_coordinates(agent, model)
    if agent.pos[1] != agent.pos[2]
        a = LightOSM.to_cartesian(get_geoloc(agent.pos[1], model))
        b = LightOSM.to_cartesian(get_geoloc(agent.pos[2], model))
        dist = norm(b .- a)
        return a + (b .- a) * agent.pos[3] / dist
    else
        return LightOSM.to_cartesian(get_geoloc(agent.pos[1], model))
    end
end

"""
    OSM.road_length(start::Int, finish::Int, model)
    OSM.road_length(pos::Tuple{Int,Int,Float64}, model)

Return the road length (in meters) between two intersections given by intersection ids.
"""
road_length(pos::Tuple{Int,Int,Float64}, model::ABM{<:OpenStreetMapSpace}) =
    road_length(pos[1], pos[2], model)
road_length(p1::Int, p2::Int, model::ABM{<:OpenStreetMapSpace}) =
    disance(model.space.map.nodes[p1], model.space.map.nodes[p2])

function Agents.is_stationary(agent, model::ABM{<:OpenStreetMapSpace})
    return !haskey(model.space.routes, agent.id)
end

# HELPERS, NOT EXPORTED
function random_point_in_bounds(model::ABM{<:OpenStreetMapSpace})
    bounds = model.space.map.kdtree.hyper_rec
    return (
        rand(model.rng) * (bounds.maxes[1] - bounds.mins[1]) + bounds.mins[1],
        rand(model.rng) * (bounds.maxes[2] - bounds.mins[2]) + bounds.mins[2],
    )
end

"""
    get_geoloc(pos::Int, model::ABM{<:OpenStreetMapSpace})

Return `GeoLocation` corresponding to node `pos`
"""
get_geoloc(pos::Int, model::ABM{<:OpenStreetMapSpace}) = model.space.map.nodes[pos].location

"""
    get_graph_vertex(pos::Int, model::ABM{<:OpenStreetMapSpace})

Return graph vertex corresponding to node `pos`
"""
get_graph_vertex(pos::Int, model::ABM{<:OpenStreetMapSpace}) = model.space.map.node_to_index[pos]

"""
    get_reverse_direction(pos::Tuple{Int,Int,Float64}, model::ABM{<:OpenStreetMapSpace})

Returns the same position, but with `pos[1]` and `pos[2]` swapped and `pos[3]` updated accordingly
"""
get_reverse_direction(pos::Tuple{Int,Int,Float64}, model::ABM{<:OpenStreetMapSpace}) =
    (pos[2], pos[1], road_length(pos, model) - pos[3])

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

    # branching here corresponds to nesting of the following cases:
    # - Is the agent moving to the end of the road or somewhere in the middle (isempty(osmpath.route))
    # - Is `distance` more than the distance to the next waypoint / end of route (will it overshoot)?
    #   - Did we reach the end of the route? If so, does the agent need to return?
    #     - If the agent returns, what direction does it go in?
    #   - If we have another waypoint after this, move there
    # It might be easier to formulate this as a recursive structure, so recursive calls are annotated where necessary
    # instead of the loop this currently runs in. These annotations are marked with `##` just to make it clear.

    osmpath = model.space.routes[agent.id]
    while distance > 0
        if isempty(osmpath.route)   # last leg of route, to the middle of a road
            # distance left to reach dest
            dist_left = osmpath.dest[3] - agent.pos[3]
            if dist_left < distance # can overshoot destination
                distance -= dist_left
                move_agent!(agent, osmpath.dest, model) # reach destination
                if osmpath.has_to_return    # if we have to return
                    osmpath = OpenStreetMapPath(    # construct return path
                        osmpath.return_route,
                        osmpath.dest,
                        osmpath.start,
                        Int[],
                        false
                    )
                    # get next waypoint on return path
                    # this will either one of the endpoints of this road
                    next_wp = osmpath.route[end]
                    if next_wp == agent.pos[1]
                        # need to go back along same road, so reverse direction
                        move_agent!(
                            agent,
                            get_reverse_direction(agent.pos, model),
                            model
                        )
                    end
                    # move remaining distance along return path
                    continue
                    ## return Agents.move_along_route!(agent, model, distance)
                end
                # delete path data so this agent is recognized as stationary
                delete!(model.space.routes, agent.id)
                break
                ## return
            end
            # can't directly reach destination, so move distance along road
            # ensure we don't overshoot the destination
            result_pos = min(agent.pos[3] + distance, osmpath.dest[3])
            move_agent!(agent, (agent.pos[1:2]..., result_pos), model)
            break
            ## return
        end
        # don't need an else clause, since everything going inside the if clause will break
        # or continue

        # distance left till next node
        dist_left = road_length(agent.pos, model) - agent.pos[3]
        if dist_left < distance # can overshoot
            distance -= dist_left   # leftover distance
            node_a = pop!(osmpath.route)    # remove the node we just reached
            if isempty(osmpath.route)
                # this was the last node, so either we reached the end or dest is on an outgoing road
                if osmpath.dest[1] == osmpath.dest[2]   # we reached the end
                    if osmpath.has_to_return    # need to return from here
                        osmpath = OpenStreetMapPath(
                            osmpath.return_route,
                            osmpath.dest,
                            osmpath.start,
                            Int[],
                            false,
                        )
                        # next node on return path
                        node_b = osmpath.route[end]
                        # set to move along reverse path
                        move_agent!(agent, (node_a, node_b, 0.0), model)
                        # move rest of distance along return route
                        ## return Agents.move_along_route!(agent, model, distance)
                        continue
                    end
                    # remove route so agent is marked as stationary
                    delete!(model.space.routes, agent.id)
                    ## return
                    break
                end

                # destination is on an outgoing road from this last waypoint
                # move to beginning of this road
                move_agent!(agent, (osmpath.dest[1:2], 0.0), model)
                # move rest of distance to destination
                ## return Agents.move_along_route!(agent, model, distance)
                continue
            end

            # there is a further waypoint
            node_b = osmpath.route[end]
            move_agent!(agent, (node_a, node_b, 0.0), model)
            # move rest of distance to next waypoint
            ## return Agents.move_along_route!(agent, model, distance)
            continue
        end

        # will not overshoot
        result_pos = min(agent.pos[3] + distance, road_length(agent.pos, model))
        move_agent!(agent, (agent.pos[1:2], result_pos), model)
        ## return
        break
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
    neighborfn(model.space.map.graph, get_graph_vertex(position, model))
end

end # module OSM

const OpenStreetMapSpace = OSM.OpenStreetMapSpace

const OSMSpace = OSM.OpenStreetMapSpace

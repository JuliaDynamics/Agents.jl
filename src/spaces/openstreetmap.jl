export OpenStreetMapSpace, OSMPos, OSMSpace
export osm_random_direction, osm_plan_route, osm_map_coordinates, osm_road_length

struct OpenStreetMapSpace <: DiscreteSpace
    m::OpenStreetMapX.MapData
    edges::Vector{CartesianIndex{2}} #So far, only helpful for osm_random_direction
    s::Vector{Vector{Int}}
end

"""
    OpenStreetMapSpace(path::AbstractString; kwargs...)
Create a space residing on the Open Street Map (OSM) file provided via `path`.

The abbreviation `OSMSpace` may be used interchangably.

Much of the functionality of this space is provided by interfacing with
[OpenStreetMapX.jl](https://github.com/pszufe/OpenStreetMapX.jl), for example the two
keyword arguments `use_cache = false` and `trim_to_connected_graph = true` are
passed into the [`OpenStreetMapX.get_map_data`](@ref) function.
For details on how to obtain an OSM file for your use case, consult the OpenStreetMapX.jl
Readme.
"""
function OpenStreetMapSpace(
    path::AbstractString;
    use_cache = false,
    trim_to_connected_graph = true,
)
    m = get_map_data(
        path; use_cache, trim_to_connected_graph,
    )
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

struct OSMPos
    start::Int
    finish::Int
    p::Float64
end

"""
    OSMPos(start::Int, finish::Int = start, p::Float64 = 0)

A helper to provide the correct `pos` format for [`AbstractAgent`](@ref) structs which
are used in conjuction with [`OpenStreetMapSpace`](@ref).
It represents the position of the agent on a road connecting the two nodes of the map
`start, finish` with percentage `p ∈ [0, 1]` along this road.
"""
OSMPos(start::Int, finish::Int = src, p::Float64 = 0.0) = OSMPos(start, finish, p)

#######################################################################################
# Custom functions for OSMSpace
#######################################################################################

# EXPORTED
"""
    osm_random_direction(model::ABM{A,OpenStreetMapSpace})

Similar to `random_position`, but rather than providing only inetersections, this method
returns a location somewhere on a road heading in a random direction.
"""
function osm_random_direction(model::ABM{<:AbstractAgent,<:OpenStreetMapSpace})
    edge = rand(model.space.edges)
    (edge.I..., rand() * model.space.m.w[edge])
end

"""
    osm_plan_route(start, finish, model)

Generate a list of intersections between the `start` and `finish` positions on the map.
"""
function osm_plan_route(start::Int, finish::Int, model::ABM{A,OpenStreetMapSpace}) where {A}
    #TODO: Expand to allow 'fastest_route' as well
    route =
        shortest_route(model.space.m, model.space.m.n[start], model.space.m.n[finish])[1]
    map(p -> getindex(model.space.m.v, p), route)
end

"""
    osm_map_coordinates(agent, model::ABM{A,OpenStreetMapSpace})

Return a set of coordinates for an agent on the underlying map. Useful for plotting.
"""
function osm_map_coordinates(agent, model)
    if agent.pos[1] != agent.pos[2]
        start = get_ENU(agent.pos[1], model)
        finish = get_ENU(agent.pos[2], model)
        travelled = agent.pos[3] / Agents.osm_road_length(agent.pos, model)
        (
            getX(start) * (1 - travelled) + getX(finish) * travelled,
            getY(start) * (1 - travelled) + getY(finish) * travelled,
        )
    else
        position = get_ENU(agent.pos[1], model)
        (getX(position), getY(position))
    end
end

"""
    osm_road_length(pos::OSMPos, model)
    osm_road_length(start::Int, finish::Int, model)

Returns the distance travelled between two intersections.
"""
osm_road_length(pos::OSMPos, model::ABM{<:AbstractAgent,<:OpenStreetMapSpace}) =
    osm_road_length(pos[1], pos[2], model)
osm_road_length(p1::Int, p2::Int, model::ABM{<:AbstractAgent,<:OpenStreetMapSpace}) =
    model.space.m.w[p1, p2]

#HELPERS, NOT EXPORTED

get_ENU(pos::Int, model) = model.space.m.nodes[model.space.m.n[pos]]

#######################################################################################
# Agents.jl space API
#######################################################################################

random_position(model::ABM{<:AbstractAgent,<:OpenStreetMapSpace}) =
    OSMPos(rand(1:nv(model)))

function add_agent_to_space!(
    agent::A,
    model::ABM{A,<:OpenStreetMapSpace},
) where {A<:AbstractAgent}
    push!(model.space.s[agent.pos[1]], agent.id)
    return agent
end

function remove_agent_from_space!(
    agent::A,
    model::ABM{A,<:OpenStreetMapSpace},
) where {A<:AbstractAgent}
    prev = model.space.s[agent.pos[1]]
    ai = findfirst(i -> i == agent.id, prev)
    deleteat!(prev, ai)
    return agent
end

function move_agent!(agent::A, pos::OSMPos, model::ABM{A,<:OpenStreetMapSpace}) where {A}
    remove_agent_from_space!(agent, model)
    agent.pos = pos
    add_agent_to_space!(agent, model)
end

"""
    move_agent!(agent::A, model::ABM{A, OpenStreetMapSpace}, distance::Real)

`distance` travelled in meters along an agents current route.
"""
function move_agent!(
    agent::A,
    model::ABM{A,<:OpenStreetMapSpace},
    distance::Real,
) where {A<:AbstractAgent}

    #TODO: Assumption that an agent can only end its route on an intersection.
    #It cannot pull up to someone's house, or park on the side of the road at present.
    if agent.pos[1] == agent.pos[2] && length(agent.route) > 0
        return nothing
    end

    dist_to_intersection = osm_road_length(agent.pos, model) - agent.pos[3]

    if distance >= dist_to_intersection
        if length(agent.route) > 0
            pos = travel!(
                agent.pos[2],
                popfirst!(agent.route),
                distance - dist_to_intersection,
                agent,
                model,
            )
        else
            # arrive at destination
            pos = OSMPos(agent.pos[2])
        end
    else
        # move up current path
        pos = (agent.pos[1], agent.pos[2], agent.pos[3] + distance)
    end

    move_agent!(agent, pos, model)
end

function travel!(start, finish, distance, agent, model)
    #assumes we have just reached the intersection of `start` and `finish`,
    #and have `distance` left to travel.
    edge_distance = osm_road_length(start, finish, model)
    if edge_distance <= distance
        if length(agent.route) > 0
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

# Nearby positions must be intersections, since edges imply a direction.
# nearby agents/ids can be on an intersection or on a road X m away.
# We cannot simply use nearby_positions to collect nearby ids then.

#TODO: Default is backwards and forwards. I assume it would be useful to turn off one or the other at some point
function nearby_ids(
    pos::OSMPos,
    model::ABM{A,<:OpenStreetMapSpace},
    distance::Real,
    args...;
    kwargs...,
) where {A}
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
    nearby
end

function ids_on_road(
    pos1::Int,
    pos2::Int,
    model::ABM{A,<:OpenStreetMapSpace},
    reverse = false,
) where {A}
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
    model::ABM{A,<:OpenStreetMapSpace},
    args...;
    kwargs...,
) where {A<:AbstractAgent}
    all = nearby_ids(agent.pos, model, args...; kwargs...)
    filter!(i -> i ≠ agent.id, all)
end

#TODO: this gives us 'nearby' intersections based on the connectivity graph.
#We could extend this using a `r`adius, and filter the list so that it returns
#"nearby intersections within radius `r`"
nearby_positions(pos::OSMPos, model, args...; kwargs...) =
    nearby_positions(pos[1], model, args...; kwargs...)

function nearby_positions(
    position::Int,
    model::ABM{A,<:OpenStreetMapSpace};
    neighbor_type::Symbol = :default,
) where {A}
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

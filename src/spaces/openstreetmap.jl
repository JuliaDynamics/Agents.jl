export OpenStreetMapSpace

struct OpenStreetMapSpace <: DiscreteSpace
    m::OpenStreetMapX.MapData
    graph::SimpleDiGraph
    s::Vector{Vector{Int}}
end

function OpenStreetMapSpace(path::AbstractString)
    m = get_map_data(path, use_cache=false, trim_to_connected_graph=true)
    agent_positions = [Int[] for i in 1:LightGraphs.nv(m.g)]
    return OpenStreetMapSpace(m, m.g, agent_positions)
end

function Base.show(io::IO, s::OpenStreetMapSpace)
    print(
        io,
        "OpenStreetMapSpace with $(length(s.m.roadways)) roadways and $(length(s.m.intersections)) intersections",
    )
end

#######################################################################################
# Agents.jl space API
#######################################################################################

#TODO: These are all IDENTICAL to graph space.
random_position(model::ABM{<:AbstractAgent,<:OpenStreetMapSpace}) = rand(1:nv(model))


function remove_agent_from_space!(
        agent::A,
        model::ABM{A,<:OpenStreetMapSpace},
    ) where {A<:AbstractAgent}
    agentpos = agent.pos
    ids = ids_in_position(agentpos, model)
    splice!(ids, findfirst(a -> a == agent.id, ids))
    return model
end

function move_agent!(
        agent::A,
        pos::ValidPos,
        model::ABM{A,<:OpenStreetMapSpace},
    ) where {A<:AbstractAgent}
    oldpos = agent.pos
    ids = ids_in_position(oldpos, model)
    splice!(ids, findfirst(a -> a == agent.id, ids))
    agent.pos = pos
    push!(ids_in_position(agent.pos, model), agent.id)
    return agent
end

ids_in_position(n::Integer, model::ABM{A,<:OpenStreetMapSpace}) where {A} = model.space.s[n]
# NOTICE: The return type of `ids_in_position` must support `length` and `isempty`!

positions(model::ABM{<:AbstractAgent,<:OpenStreetMapSpace}) = 1:nv(model)


function nearby_ids(pos::Int, model::ABM{A,<:OpenStreetMapSpace}, args...; kwargs...) where {A}
    np = nearby_positions(pos, model, args...; kwargs...)
    # This call is faster than reduce(vcat, ..), or Iterators.flatten
    vcat(model.space.s[pos], model.space.s[np]...)
end

function nearby_ids(agent::A, model::ABM{A,<:OpenStreetMapSpace}, args...; kwargs...) where {A<:AbstractAgent}
    all = nearby_ids(agent.pos, model, args...; kwargs...)
    filter!(i -> i ≠ agent.id, all)
end

function nearby_positions(
        position::Integer,
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
    neighborfn(model.space.graph, position)
end

function nearby_positions(
        position::Integer,
        model::ABM{A,<:OpenStreetMapSpace},
        radius::Integer;
        kwargs...,
    ) where {A}
    output = copy(nearby_positions(position, model; kwargs...))
    for _ in 2:radius
        newnps = (nearby_positions(np, model; kwargs...) for np in output)
        append!(output, reduce(vcat, newnps))
        unique!(output)
    end
    filter!(i -> i != position, output)
end

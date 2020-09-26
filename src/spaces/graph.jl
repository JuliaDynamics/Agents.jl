export GraphSpace

#######################################################################################
# Basic space definition
#######################################################################################
struct GraphSpace{G} <: DiscreteSpace
    graph::G
    s::Vector{Vector{Int}}
end

"""
    GraphSpace(graph::AbstractGraph)
Create a `GraphSpace` instance that is underlined by an arbitrary graph from
[LightGraphs.jl](https://github.com/JuliaGraphs/LightGraphs.jl).
The position type for this space is `Int`.

The nodes of the graph space can be altered with the functions [`add_node!`](@ref),
[`rem_node!`](@ref) and [`add_edge`](@ref), assuming the used graph is mutable.

`GraphSpace` represents a space where each node of a graph can hold an arbitrary
amount of agents, and each agent can move between the nodes of the graph.
If you want to model social networks, where each agent is equivalent with a node of
a graph, you're better of using `nothing` (or other spaces) as the model space, and using
a graph from LightGraphs.jl directly in the model parameters, as shown in the
[Social networks with LightGraphs.jl](@ref) integration example.
"""
function GraphSpace(graph::G) where {G<:AbstractGraph}
    agent_positions = [Int[] for i in 1:LightGraphs.nv(graph)]
    return GraphSpace{G}(graph, agent_positions)
end

"""
    nv(model::ABM)
Return the number of positions (vertices) in the `model` space.
"""
LightGraphs.nv(abm::ABM{<:Any,<:GraphSpace}) = LightGraphs.nv(abm.space.graph)

"""
    ne(model::ABM)
Return the number of edges in the `model` space.
"""
LightGraphs.ne(abm::ABM{<:Any,<:GraphSpace}) = LightGraphs.ne(abm.space.graph)

function Base.show(io::IO, s::GraphSpace)
    print(
        io,
        "GraphSpace with $(nv(s.graph)) positions and $(ne(s.graph)) edges",
    )
end

#######################################################################################
# Agents.jl space API
#######################################################################################
random_position(model::ABM{<:AbstractAgent,<:GraphSpace}) = rand(1:nv(model))

function remove_agent_from_space!(
    agent::A,
    model::ABM{A,<:GraphSpace},
) where {A<:AbstractAgent}
    agentpos = agent.pos
    ids = ids_in_position(agentpos, model)
    splice!(ids, findfirst(a -> a == agent.id, ids))
    return model
end

function move_agent!(
    agent::A,
    pos::ValidPos,
    model::ABM{A,<:GraphSpace},
) where {A<:AbstractAgent}
    oldpos = agent.pos
    ids = ids_in_position(oldpos, model)
    splice!(ids, findfirst(a -> a == agent.id, ids))
    agent.pos = pos
    push!(ids_in_position(agent.pos, model), agent.id)
    return agent
end

function add_agent_to_space!(
    agent::A,
    model::ABM{A,<:DiscreteSpace},
) where {A<:AbstractAgent}
    push!(ids_in_position(agent.pos, model), agent.id)
    return agent
end

# The following two is for the discrete space API:
ids_in_position(n::Integer, model::ABM{A,<:GraphSpace}) where {A} = model.space.s[n]
# NOTICE: The return type of `ids_in_position` must support `length` and `isempty`!

positions(model::ABM{<:AbstractAgent,<:GraphSpace}) = 1:nv(model)

#######################################################################################
# Neighbors
#######################################################################################
function nearby_ids(pos::Int, model::ABM{A,<:GraphSpace}, args...; kwargs...) where {A}
    np = nearby_positions(pos, model, args...; kwargs...)
    # This call is faster than reduce(vcat, ..), or Iterators.flatten
    vcat(model.space.s[pos], model.space.s[np]...)
end

function nearby_ids(agent::A, model::ABM{A,<:GraphSpace}, args...; kwargs...) where {A<:AbstractAgent}
    all = nearby_ids(agent.pos, model, args...; kwargs...)
    filter!(i -> i ≠ agent.id, all)
end

function nearby_positions(
    position::Integer,
    model::ABM{A,<:GraphSpace};
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
    model::ABM{A,<:GraphSpace},
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

#######################################################################################
# Mutable graph functions
#######################################################################################

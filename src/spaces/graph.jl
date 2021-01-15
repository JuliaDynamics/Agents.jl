export GraphAgent, GraphSpace

"""
    @agent Person GraphAgent begin
        age::Int
    end

Create an agent with the ability to operate on a [`GraphSpace`](@ref). Used in
conjunction with [`@agent`](@ref) the example above produces

```julia
mutable struct Person <: AbstractAgent
    id::Int
    pos::Int
    age::Int
end
```
"""
mutable struct GraphAgent <: AbstractAgent
    id::Int
    pos::Int
end

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

The underlying graph can be altered using [`add_node!`](@ref) and [`rem_node!`](@ref).

`GraphSpace` represents a space where each node (i.e. position) of a graph can hold an arbitrary
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
LightGraphs.nv(space::GraphSpace) = LightGraphs.nv(space.graph)

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
export rem_node!, add_node!, add_edge!

"""
    rem_node!(model::ABM{A, <: GraphSpace}, n::Int)
Remove node (i.e. position) `n` from the model's graph. All agents in that node are killed.

**Warning:** LightGraphs.jl (and thus Agents.jl) swaps the index of the last node with
that of the one to be removed, while every other node remains as is. This means that
when doing `rem_node!(n, model)` the last node becomes the `n`-th node while the previous
`n`-th node (and all its edges and agents) are deleted.
"""
function rem_node!(model::ABM{<:AbstractAgent, <: GraphSpace}, n::Int)
    for id ∈ copy(ids_in_position(n, model)); kill_agent!(model[id], model); end
    V = nv(model)
    success = LightGraphs.rem_vertex!(model.space.graph, n)
    n > V && error("Node number exceeds amount of nodes in graph!")
    s = model.space.s
    s[V], s[n] = s[n], s[V]
    pop!(s)
end

"""
    add_node!(model::ABM{A, <: GraphSpace})
Add a new node (i.e. possible position) to the model's graph and return it.
You can connect this new node with existing ones using [`add_edge!`](@ref).
"""
function add_node!(model::ABM{<:AbstractAgent, <: GraphSpace})
    add_vertex!(model.space.graph)
    push!(model.space.s, Int[])
    return nv(model)
end

"""
    add_edge!(model::ABM{A, <: GraphSpace}, n::Int, m::Int)
Add a new edge (relationship between two positions) to the graph.
Returns a boolean, true if the operation was succesful.
"""
LightGraphs.add_edge!(model, n, m) = add_edge!(model.space.graph, n, m)

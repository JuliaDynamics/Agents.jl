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
[Graphs.jl](https://github.com/JuliaGraphs/Graphs.jl).
The position type for this space is `Int`, use [`GraphAgent`](@ref) for convenience.
The underlying graph can be altered using [`add_node!`](@ref) and [`rem_node!`](@ref).

`GraphSpace` represents a space where each node (i.e. position) of a graph can hold an arbitrary
amount of agents, and each agent can move between the nodes of the graph.
An example of its usage can be found in [SIR model for the spread of COVID-19](@ref).

If you want to model social networks, where each agent is equivalent with a node of
a graph, you're better of using `nothing` (or other spaces) as the model space, and using
a graph from Graphs.jl directly in the model parameters, as shown in the
[Social networks with Graphs.jl](@ref) integration example.
"""
function GraphSpace(graph::G) where {G <: AbstractGraph}
    agent_positions = [Int[] for i in 1:Graphs.nv(graph)]
    return GraphSpace{G}(graph, agent_positions)
end

function Base.show(io::IO, s::GraphSpace)
    print(io, "GraphSpace with $(nv(s.graph)) positions and $(ne(s.graph)) edges")
end

#######################################################################################
# Agents.jl space API
#######################################################################################
random_position(model::ABM{<:GraphSpace}) = rand(model.rng, 1:nv(model))

function remove_agent_from_space!(
    agent::A,
    model::ABM{<:GraphSpace,A},
) where {A <: AbstractAgent}
    agentpos = agent.pos
    ids = ids_in_position(agentpos, model)
    splice!(ids, findfirst(a -> a == agent.id, ids))
    return model
end

function add_agent_to_space!(
    agent::A,
    model::ABM{<:DiscreteSpace,A},
) where {A <: AbstractAgent}
    push!(ids_in_position(agent.pos, model), agent.id)
    return agent
end

# The following is for the discrete space API:
ids_in_position(n::Integer, model::ABM{<:GraphSpace}) = model.space.s[n]
# NOTICE: The return type of `ids_in_position` must support `length` and `isempty`!

#######################################################################################
# Neighbors
#######################################################################################
function nearby_ids(pos::Int, model::ABM{<:GraphSpace}, r = 1; kwargs...)
    if r == 0
        return ids_in_position(pos, model)
    end
    np = nearby_positions(pos, model, r; kwargs...)
    vcat(model.space.s[pos], model.space.s[np]...)
end

# This function is here purely because of performance reasons
function nearby_ids(agent::A, model::ABM{<:GraphSpace,A}, r = 1; kwargs...) where {A <: AbstractAgent}
    all = nearby_ids(agent.pos, model, r; kwargs...)
    filter!(i -> i ≠ agent.id, all)
end

function nearby_positions(
    position::Integer,
    model::ABM{<:GraphSpace};
    neighbor_type::Symbol = :default,
)
    @assert neighbor_type ∈ (:default, :all, :in, :out)
    if neighbor_type == :default
        Graphs.neighbors(model.space.graph, position)
    elseif neighbor_type == :in
        Graphs.inneighbors(model.space.graph, position)
    elseif neighbor_type == :out
        Graphs.outneighbors(model.space.graph, position)
    else
        Graphs.all_neighbors(model.space.graph, position)
    end
end

#######################################################################################
# Mutable graph functions
#######################################################################################
export rem_node!, add_node!, add_edge!

"""
    rem_node!(model::ABM{<: GraphSpace}, n::Int)
Remove node (i.e. position) `n` from the model's graph. All agents in that node are killed.

**Warning:** Graphs.jl (and thus Agents.jl) swaps the index of the last node with
that of the one to be removed, while every other node remains as is. This means that
when doing `rem_node!(n, model)` the last node becomes the `n`-th node while the previous
`n`-th node (and all its edges and agents) are deleted.
"""
function rem_node!(model::ABM{<:GraphSpace}, n::Int)
    for id in copy(ids_in_position(n, model))
        kill_agent!(model[id], model)
    end
    V = nv(model)
    success = Graphs.rem_vertex!(model.space.graph, n)
    n > V && error("Node number exceeds amount of nodes in graph!")
    s = model.space.s
    s[V], s[n] = s[n], s[V]
    pop!(s)
end

"""
    add_node!(model::ABM{<: GraphSpace})
Add a new node (i.e. possible position) to the model's graph and return it.
You can connect this new node with existing ones using [`add_edge!`](@ref).
"""
function add_node!(model::ABM{<:GraphSpace})
    add_vertex!(model.space.graph)
    push!(model.space.s, Int[])
    return nv(model)
end

"""
    add_edge!(model::ABM{<: GraphSpace}, n::Int, m::Int)
Add a new edge (relationship between two positions) to the graph.
Returns a boolean, true if the operation was succesful.
"""
Graphs.add_edge!(model, n, m) = add_edge!(model.space.graph, n, m)

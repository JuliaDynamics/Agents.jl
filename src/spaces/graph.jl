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
"""
function GraphSpace(graph::G) where {G<:AbstractGraph}
    agent_positions = [Int[] for i in 1:LightGraphs.nv(graph)]
    return GraphSpace{G}(graph, agent_positions)
end

"""
    nv(model::ABM)
Return the number of nodes (vertices) in the `model` space.
"""
LightGraphs.nv(abm::ABM{<:Any,<:GraphSpace}) = LightGraphs.nv(abm.space.graph)

"""
    ne(model::ABM)
Return the number of edges in the `model` space.
"""
LightGraphs.ne(abm::ABM{<:Any,<:GraphSpace}) = LightGraphs.ne(abm.space.graph)

function Base.show(io::IO, space::GraphSpace)
    print(
        io,
        "$(nameof(typeof(space))) with $(nv(space.graph)) nodes and $(ne(space.graph)) edges",
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
    agentnode = agent.pos
    p = get_node_contents(agentnode, model)
    splice!(p, findfirst(a -> a == agent.id, p))
    return model
end

function move_agent!(
    agent::A,
    pos::ValidPos,
    model::ABM{A,<:GraphSpace},
) where {A<:AbstractAgent}
    oldnode = agent.pos
    p = get_node_contents(oldnode, model)
    splice!(p, findfirst(a -> a == agent.id, p))
    agent.pos = pos
    push!(get_node_contents(agent.pos, model), agent.id)
    return agent
end

function add_agent_to_space!(
    agent::A,
    model::ABM{A,<:DiscreteSpace},
) where {A<:AbstractAgent}
    push!(get_node_contents(agent.pos, model), agent.id)
    return agent
end

# The following two is for the discrete space API:
"""
    get_node_contents(position, model::ABM{A, <:DiscreteSpace})

Return the ids of agents in the "node" corresponding to `position`.
"""
get_node_contents(n::Integer, model::ABM{A,<:GraphSpace}) where {A} = model.space.s[n]
# NOTICE: The return type of `get_node_contents` must support `length` and `isempty`!

nodes(model::ABM{<:AbstractAgent,<:GraphSpace}) = 1:nv(model)

#######################################################################################
# Neighbors
#######################################################################################
function space_neighbors(pos::Int, model::ABM{A,<:GraphSpace}, args...; kwargs...) where {A}
    nn = node_neighbors(pos, model, args...; kwargs...)
    # TODO: Use flatten here or something for performance?
    # `model.space.s[nn]...` allocates, because it creates a new array!
    # Also `vcat` allocates a second time
    # We include the current node in the search since we are searching over space
    vcat(model.space.s[pos], model.space.s[nn]...)
end

function node_neighbors(
    node_number::Integer,
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
    neighborfn(model.space.graph, node_number)
end

function node_neighbors(
    node_number::Integer,
    model::ABM{A,<:GraphSpace},
    radius::Integer;
    kwargs...,
) where {A}
    neighbor_nodes = Set(node_neighbors(node_number, model; kwargs...))
    included_nodes = Set()
    for rad in 2:radius
        templist = Vector{Int}()
        for nn in neighbor_nodes
            if !in(nn, included_nodes)
                newns = node_neighbors(nn, model; kwargs...)
                for newn in newns
                    push!(templist, newn)
                end
            end
        end
        for tt in templist
            push!(neighbor_nodes, tt)
        end
    end
    nlist = collect(neighbor_nodes)
    j = findfirst(a -> a == node_number, nlist)
    if j != nothing
        deleteat!(nlist, j)
    end
    return nlist
end

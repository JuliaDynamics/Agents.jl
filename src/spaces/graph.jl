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
LightGraphs.nv(abm::ABM{<:Any, <:GraphSpace}) = LightGraphs.nv(abm.space.graph)

"""
    ne(model::ABM)
Return the number of edges in the `model` space.
"""
LightGraphs.nv(abm::ABM{<:Any, <:GraphSpace}) = LightGraphs.ne(abm.space.graph)

function Base.show(io::IO, abm::GraphSpace)
    s = "$(nameof(typeof(abm))) with $(nv(abm)) nodes and $(ne(abm)) edges"
    print(io, s)
end


#######################################################################################
# Agents.jl space API
#######################################################################################
random_position(model::ABM{<:AbstractAgent, <:GraphSpace}) = rand(1:nv(model)

function remove_agent_from_space!(agent::A, model::ABM{A,<:GraphSpace}) where {A<:AbstractAgent}
    agentnode = agent.pos
    p = get_node_contents(agentnode, model)
    splice!(p, findfirst(a -> a == agent.id, p))
    return model
end

function move_agent!(agent::A, pos::ValidPos, model::ABM{A,<:GraphSpace}) where {A<:AbstractAgent}
    oldnode = agent.pos, model
    p = get_node_contents(oldnode, model)
    splice!(p, findfirst(a -> a == agent.id, p))
    agent.pos = pos
    push!(get_node_contents(agent.pos, model), agent.id)
    return agent
end

function add_agent_to_space!(agent::A, model::ABM{A,<:DiscreteSpace}) where {A<:AbstractAgent}
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

nodes(model::ABM{<:AbstractAgent, GraphSpace}) = 1:nv(model)

#######################################################################################
# Neighbors TODO
#######################################################################################
function space_neighbors(agent::A, model::ABM{A,<:DiscreteSpace}, args...; kwargs...) where {A<:AbstractAgent}
  all = space_neighbors(agent.pos, model, args...; kwargs...)
  d = findfirst(isequal(agent.id), all)
  d ≠ nothing && deleteat!(all, d)
  return all
end

function space_neighbors(pos, model::ABM{A, <: DiscreteSpace}, args...; kwargs...) where {A<:AbstractAgent}
  node = coord2vertex(pos, model)
  nn = node_neighbors(node, model, args...; kwargs...)
  # We include the current node in the search since we are searching over space
  # TODO: Use flatten here or something
  vcat(agent_positions(model)[node], agent_positions(model)[nn]...)
end

"""
    node_neighbors(node, model::ABM{A, <:DiscreteSpace}, r = 1) → nodes
Return all nodes that are neighbors to the given `node`, which can be an `Int` for
[`GraphSpace`](@ref), or a `NTuple{Int}` for [`GridSpace`](@ref).
Use [`vertex2coord`](@ref) to convert nodes to positions for `GridSpace`.

    node_neighbors(agent, model::ABM{A, <:DiscreteSpace}, r = 1) → nodes
Same as above, but uses `agent.pos` as `node`.

Keyword argument `neighbor_type=:default` can be used to select differing neighbors
depending on the underlying graph directionality type.
- `:default` returns neighbors of a vertex. If graph is directed, this is equivalent
to `:out`. For undirected graphs, all options are equivalent to `:out`.
- `:all` returns both `:in` and `:out` neighbors.
- `:in` returns incoming vertex neighbors.
- `:out` returns outgoing vertex neighbors.
"""
node_neighbors(
    agent::AbstractAgent,
    model::ABM{A,<:DiscreteSpace},
    args...;
    kwargs...,
) where {A} = node_neighbors(agent.pos, model, args...; kwargs...)
function node_neighbors(node_number::Integer, model::ABM{A, <: DiscreteSpace}; neighbor_type::Symbol=:default) where {A}
    @assert neighbor_type ∈ (:default, :all, :in, :out)
    neighborfn =
        if neighbor_type == :default
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

function node_neighbors(node_coord::Tuple, model::ABM{A, <: DiscreteSpace}; kwargs...) where {A}
  node_number = coord2vertex(node_coord, model)
  nn = node_neighbors(node_number, model; kwargs...)
  nc = [vertex2coord(i, model) for i in nn]
  return nc
end

function node_neighbors(node_number::Integer, model::ABM{A, <: DiscreteSpace}, radius::Integer; kwargs...) where {A}
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
  j = findfirst(a-> a==node_number, nlist)
  if j != nothing
    splice!(nlist, j)
  end
  return nlist
end

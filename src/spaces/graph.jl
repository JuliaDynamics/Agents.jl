export node_neighbors, find_empty_nodes, pick_empty, has_empty_nodes, get_node_contents,
NodeIterator, space_neighbors, nodes, get_node_agents, coord2vertex, vertex2coord
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

"""
    get_node_contents(position, model::ABM{A, <:DiscreteSpace})

Return the ids of agents in the "node" corresponding to `position`.
"""
get_node_contents(n::Integer, model::ABM{A,<:GraphSpace}) where {A} = model.space.s[n]

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

#######################################################################################
# Extra space-related functions dedicated to discrete space
#######################################################################################
export add_agent_single!, fill_space!, move_agent_single!

"""
    add_agent_single!(agent::A, model::ABM{A, <: DiscreteSpace}) → agent

Add agent to a random node in the space while respecting a maximum one agent per node.
This function throws a warning if no empty nodes remain.
"""
function add_agent_single!(agent::A, model::ABM{A,<:DiscreteSpace}) where {A<:AbstractAgent}
    empty_cells = find_empty_nodes(model)
    if length(empty_cells) > 0
        agent.pos = correct_pos_type(rand(empty_cells), model)
        add_agent_pos!(agent, model)
    else
        @warn "No empty nodes found for `add_agent_single!`."
    end
end

"""
    add_agent_single!(model::ABM{A, <: DiscreteSpace}, properties...; kwargs...)
Same as `add_agent!(model, properties...)` but ensures that it adds an agent
into a node with no other agents (does nothing if no such node exists).
"""
function add_agent_single!(
        model::ABM{A,<:DiscreteSpace},
        properties...;
        kwargs...,
    ) where {A<:AbstractAgent}
    empty_cells = find_empty_nodes(model)
    if length(empty_cells) > 0
        add_agent!(rand(empty_cells), model, properties...; kwargs...)
    end
end


"""
    fill_space!([A ,] model::ABM{A, <:DiscreteSpace}, args...; kwargs...)
    fill_space!([A ,] model::ABM{A, <:DiscreteSpace}, f::Function; kwargs...)
Add one agent to each node in the model's space. Similarly with [`add_agent!`](@ref),
the function creates the necessary agents and
the `args...; kwargs...` are propagated into agent creation.
If instead of `args...` a function `f` is provided, then `args = f(pos)` is the result of
applying `f` where `pos` is each position (tuple for grid, node index for graph).

An optional first argument is an agent **type** to be created, and targets mixed-agent
models where the agent constructor cannot be deduced (since it is a union).

## Example
```julia
using Agents
mutable struct Daisy <: AbstractAgent
    id::Int
    pos::Tuple{Int, Int}
    breed::String
end
mutable struct Land <: AbstractAgent
    id::Int
    pos::Tuple{Int, Int}
    temperature::Float64
end
space = GridSpace((10, 10), moore = true, periodic = true)
model = ABM(Union{Daisy, Land}, space)
temperature(pos) = (pos[1]/10, ) # make it Tuple!
fill_space!(Land, model, temperature)
```
"""
fill_space!(model::ABM{A}, args...; kwargs...) where {A<:AbstractAgent} =
fill_space!(A, model, args...; kwargs...)

function fill_space!(::Type{A}, model::ABM, args...; kwargs...) where {A<:AbstractAgent}
    for n in nodes(model)
        id = nextid(model)
        cnode = correct_pos_type(n, model)
        add_agent_pos!(A(id, cnode, args...; kwargs...), model)
    end
    return model
end

function fill_space!(::Type{A}, model::ABM, f::Function; kwargs...) where {A<:AbstractAgent}
    for n in nodes(model)
        id = nextid(model)
        cnode = correct_pos_type(n, model)
        args = f(cnode)
        add_agent_pos!(A(id, cnode, args...; kwargs...), model)
    end
    return model
end

"""
    move_agent_single!(agent::AbstractAgent, model::ABM{A,<:DiscreteSpace}) → agentt

Move agent to a random node while respecting a maximum of one agent
per node. If there are no empty nodes, the agent wont move.
Only valid for non-continuous spaces.
"""
function move_agent_single!(agent::A, model::ABM{A,<:DiscreteSpace}) where {A<:AbstractAgent}
    empty_cells = find_empty_nodes(model)
    if length(empty_cells) > 0
        random_node = rand(empty_cells)
        move_agent!(agent, random_node, model)
    end
    return agent
end

#######################################################################################
# finding specific nodes or agents
#######################################################################################
"""
    find_empty_nodes(model::ABM)

Returns an iterator over empty nodes (i.e. without any agents) in the model.
"""
function find_empty_nodes(model::ABM{A,<:DiscreteSpace}) where {A}
  ap = agent_positions(model)
  [i for i in 1:length(ap) if isempty(ap[i])]
end

"""
    pick_empty(model)

Return a random empty node or `0` if there are no empty nodes.
"""
function pick_empty(model::ABM{A,<:DiscreteSpace}) where {A}
  empty_nodes = find_empty_nodes(model)
  isempty(empty_nodes) && return 0
  rand(empty_nodes)
end

"""
    has_empty_nodes(model)

Return true if there are empty nodes in the `model`.
"""
function has_empty_nodes(model::ABM{A,<:DiscreteSpace}) where {A}
    any(isempty, agent_positions(model))
end

"""
    get_node_contents(agent::AbstractAgent, model)

Return all agents' ids in the same node as the `agent` (including the agent's own id).
"""
get_node_contents(agent::AbstractAgent, model::ABM{A,<:DiscreteSpace}) where {A} = get_node_contents(agent.pos, model)

function get_node_contents(coords::Tuple, model::ABM{A,<:DiscreteSpace}) where {A}
  node_number = coord2vertex(coords, model)
  agent_positions(model)[node_number]
end

"""
    get_node_agents(x, model)
Same as `get_node_contents(x, model)` but directly returns the list of agents
instead of just the list of IDs.
"""
get_node_agents(x, model::ABM{A,<:DiscreteSpace}) where {A} = [model[id] for id in get_node_contents(x, model)]

@deprecate id2agent(id::Integer, model::ABM) model[id]

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


#######################################################################################
# Iteration over space
#######################################################################################
nodes(model::ABM{<:AbstractAgent, GraphSpace}) = 1:nv(model)

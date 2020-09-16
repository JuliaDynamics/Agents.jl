export node_neighbors, find_empty_nodes, pick_empty, has_empty_nodes, get_node_contents,
NodeIterator, space_neighbors, nodes, get_node_agents, coord2vertex, vertex2coord
export nv, ne
export GraphSpace, GridSpace

#######################################################################################
# Basic space definition
#######################################################################################
abstract type DiscreteSpace <: AbstractSpace end

LightGraphs.nv(space::DiscreteSpace) = LightGraphs.nv(space.graph)
LightGraphs.ne(space::DiscreteSpace) = LightGraphs.ne(space.graph)

"""
    nv(model::ABM)
Return the number of nodes (vertices) in the `model` space.
"""
LightGraphs.nv(abm::ABM) = LightGraphs.nv(abm.space.graph)

"""
    ne(model::ABM)
Return the number of edges in the `model` space.
"""
LightGraphs.ne(abm::ABM) = LightGraphs.ne(abm.space.graph)

struct GraphSpace{G} <: DiscreteSpace
  graph::G
  agent_positions::Vector{Vector{Int}}
end
struct GridSpace{G, D, I<:Integer} <: DiscreteSpace
  graph::G # Graph
  agent_positions::Vector{Vector{Int}}
  dimensions::NTuple{D, I}
end
function Base.show(io::IO, abm::DiscreteSpace)
    s = "$(nameof(typeof(abm))) with $(nv(abm)) nodes and $(ne(abm)) edges"
    print(io, s)
end

function correct_pos_type(n, model)
    if typeof(model.space) <: GraphSpace
        return coord2vertex(n, model)
    elseif typeof(model.space) <: GridSpace
        return vertex2coord(n, model)
    end
end

agent_positions(m::ABM) = m.space.agent_positions
agent_positions(m::DiscreteSpace) = m.agent_positions
Base.size(s::GridSpace) = s.dimensions

"""
    isempty(node::Int, model::ABM)
Return `true` if there are no agents in `node`.
"""
Base.isempty(node::Integer, model::ABM) =
isempty(model.space.agent_positions[node])

"""
    GraphSpace(graph::AbstractGraph)
Create a `GraphSpace` instance that is underlined by an arbitrary graph from
[LightGraphs.jl](https://github.com/JuliaGraphs/LightGraphs.jl).
In this case, your agent type must have a `pos` field that is of type `Int`.
"""
function GraphSpace(graph::G) where {G<:AbstractGraph}
  agent_positions = [Int[] for i in 1:LightGraphs.nv(graph)]
  return GraphSpace{G}(graph, agent_positions)
end

"""
    GridSpace(dims::NTuple; periodic = false, moore = false) → GridSpace
Create a `GridSpace` instance that represents a grid of dimensionality `length(dims)`,
with each dimension having the size of the corresponding entry of `dims`.
Such grids are typically used in cellular-automata-like models.
In this case, your agent type must have a `pos` field that is of type `NTuple{N, Int}`,
where `N` is the number of dimensions.

The two keyword arguments denote if the grid should be periodic on its ends,
and if the connections should be of type Moore or not (in the Moore case
the diagonal connections are also valid. E.g. for a 2D grid, each node has
8 neighbors).
"""
function GridSpace(dims::NTuple{D, I}; periodic = false, moore = false) where {D, I}
  graph = _grid(dims..., periodic, moore)
  agent_positions = [Int[] for i in 1:LightGraphs.nv(graph)]
  return GridSpace{typeof(graph), D, I}(graph, agent_positions, dims)
end

# 1d grid
function _grid(length::Integer, periodic::Bool=false, moore::Bool = false)
  g = LightGraphs.path_graph(length)
  if periodic
    add_edge!(g, 1, length)
  end
  return g
end

# 2d grid
function _grid(x::Integer, y::Integer, periodic::Bool = false, moore::Bool = false)
  if moore
    g = _grid2d_moore(x, y, periodic)
  else
    g = LightGraphs.grid([x, y], periodic=periodic)
  end
  return g
end

function _grid2d_moore(xdim::Integer, ydim::Integer, periodic::Bool=false)
  g = LightGraphs.grid([xdim, ydim], periodic=periodic)
  for x in 1:xdim
    for y in 1:ydim
      nodeid = coord2vertex((x, y), (xdim, ydim))
      connect_to = []
      if y == ydim
        if x == 1
          if periodic
            tp = (xdim, 1); push!(connect_to, tp)
            tp = (2, ydim-1); push!(connect_to, tp)
          else
            tp = (2, ydim-1); push!(connect_to, tp)
          end
        elseif x == xdim
          if periodic
            tp = (1, 1); push!(connect_to, tp)
            tp = (xdim-1, ydim-1); push!(connect_to, tp)
          else
            tp = (xdim-1, ydim-1); push!(connect_to, tp)
          end
        else
          if periodic
            tp = (x-1, 1); push!(connect_to, tp)
            tp = (x+1, 1); push!(connect_to, tp)
            tp = (x-1, y-1); push!(connect_to, tp)
            tp = (x+1, y-1); push!(connect_to, tp)
          else
            tp = (x-1, y-1); push!(connect_to, tp)
            tp = (x+1, y-1); push!(connect_to, tp)
          end
        end
      elseif y == 1
        if x == 1
          if periodic
            tp = (xdim, ydim); push!(connect_to, tp)
            tp = (2, y+1); push!(connect_to, tp)
          else
            tp = (2, y+1); push!(connect_to, tp)
          end
        elseif x == xdim
          if periodic
            tp = (1, y); push!(connect_to, tp)
            tp = (xdim-1, y+1); push!(connect_to, tp)
          else
            tp = (xdim-1, y+1); push!(connect_to, tp)
          end
        else
          if periodic
            tp = (x-1, y+1); push!(connect_to, tp)
            tp = (x+1, y+1); push!(connect_to, tp)
            tp = (x-1, ydim); push!(connect_to, tp)
            tp = (x+1, ydim); push!(connect_to, tp)
          else
            tp = (x-1, y+1); push!(connect_to, tp)
            tp = (x+1, y+1); push!(connect_to, tp)
          end
        end
      elseif y != 1 && y != ydim && x == 1
        if periodic
          tp = (x+1, y+1); push!(connect_to, tp)
          tp = (x+1, y-1); push!(connect_to, tp)
          tp = (xdim, y+1); push!(connect_to, tp)
          tp = (xdim, y-1); push!(connect_to, tp)
        else
          tp = (x+1, y+1); push!(connect_to, tp)
          tp = (x+1, y-1); push!(connect_to, tp)
        end
      elseif y != 1 && y != ydim && x == xdim
        if periodic
          tp = (x-1, y+1); push!(connect_to, tp)
          tp = (x-1, y-1); push!(connect_to, tp)
          tp = (1, y+1); push!(connect_to, tp)
          tp = (1, y-1); push!(connect_to, tp)
        else
          tp = (x-1, y+1); push!(connect_to, tp)
          tp = (x-1, y-1); push!(connect_to, tp)
        end
      else
          tp = (x+1, y+1); push!(connect_to, tp)
          tp = (x-1, y-1); push!(connect_to, tp)
          tp = (x+1, y-1); push!(connect_to, tp)
          tp = (x-1, y+1); push!(connect_to, tp)
      end

      for pp in connect_to
        add_edge!(g, nodeid, coord2vertex((pp[1], pp[2]), (xdim, ydim)))
      end
    end
  end
  return g
end

# 3d
function _grid(x::Integer, y::Integer, z::Integer, periodic=false, moore=false)
  g = _grid(x, y, periodic, moore)
  gp = deepcopy(g)
  gv = nv(gp)
  for layer in 2:z
    factor = layer-1
    for newnode in 1:gv
      newnodeid = newnode + (factor*gv)
      connect_to = newnodeid - gv
      if newnodeid > nv(g)
        add_vertex!(g)
      end
      add_edge!(g, newnodeid, connect_to)
      for nn in neighbors(gp, newnode)
        newneighbor = nn + (factor*gv)
        if newneighbor > nv(g)
          add_vertex!(g)
        end
        add_edge!(g, newnodeid, newneighbor)
      end
    end
  end
  return g
end

#######################################################################################
# vertex ⇄ coordinates
#######################################################################################
for f in (:coord2vertex, :vertex2coord)
  @eval ($f)(c, model::ABM) = ($f)(c, model.space)
  @eval ($f)(c, space::GridSpace) = ($f)(c, space.dimensions)
  @eval ($f)(c, space::GraphSpace) =
        error("This functionality does not make sense for a GraphSpace.")
end

"""
    coord2vertex(coord::NTuple{Int}, model_or_space) → n
    coord2vertex(coord::AbstractAgent, model_or_space) → n

Return the node number `n` of the given coordinates or the agent's position.
"""
function coord2vertex end

coord2vertex(agent::AbstractAgent, model::ABM) =
coord2vertex(agent.pos, model.space)

function coord2vertex(coord::Tuple{T, T, T}, dims) where T<: Integer
  if (dims[2] == 1 && dims[3] == 1) ||
     (dims[1] == 1 && dims[3] == 1) ||
     (dims[1] == 1 && dims[2] == 1) # 1D grid
    nodeid = maximum(coord[1])
  elseif dims[1] > 1 && dims[2] > 1 && dims[3] == 1  # 2D grid
    nodeid = coord2vertex((coord[1], coord[2]), (dims[1], dims[2]))
  else # 3D grid
    nodeid = (coord[2] * dims[1]) - (dims[1] - coord[1])  # (y * xlength) - (xlength - x)
    nodeid = nodeid + ((dims[1]*dims[2]) * (coord[3]-1))
  end
  return nodeid
end

function coord2vertex(coord::Tuple{Integer,Integer}, dims::Tuple{Integer,Integer})
  nodeid = (coord[2] * dims[1]) - (dims[1] - coord[1])  # (y * xlength) - (xlength - x)
  return nodeid
end

coord2vertex(coord::Tuple{Integer}, dims) = coord[1]
coord2vertex(coord::Integer, args...) = coord
coord2vertex(coord::Integer, m::ABM) = coord

"""
    vertex2coord(vertex::Integer, model_or_space) → coords

Returns the coordinates of a node given its number on the graph.
"""
function vertex2coord end

function vertex2coord(vertex::T, dims::Tuple{Integer, Integer, Integer}) where {T<:Integer}
  if dims[1] > 1 && dims[2] == 1 && dims[3] == 1  # 1D grid
    coord = (vertex, T(1), T(1))
  elseif dims[1] > 1 && dims[2] > 1 && dims[3] == 1  # 2D grid
    coord = vertex2coord(vertex, (dims[1], dims[2]))
    coord = (coord[1], coord[2], T(1))
  elseif dims[1] > 1 && dims[2] > 1 && dims[3] > 1  # 3D grid
    gridbasesize = dims[1]*dims[2]
    zcoord = ceil(T, vertex/gridbasesize)
    vertex2d = vertex - ((zcoord-T(1)) * gridbasesize)
    coord2d = vertex2coord(vertex2d, (dims[1], dims[2]))
    coord = (T(coord2d[1]), T(coord2d[2]), zcoord)
  else
    error("Wrong coords!")
  end
  return coord
end

function vertex2coord(vertex::T, dims::Tuple{Integer,Integer}) where {T<:Integer}
  x = T(vertex % dims[1])
  if x == 0
    x = T(dims[1])
  end
  y = ceil(T, vertex/dims[1])
  return (x, y)
end

vertex2coord(v::Tuple, model::ABM) = v

#######################################################################################
# Agents.jl space API
#######################################################################################
function random_position(agent::A, model::ABM{A,<:DiscreteSpace}) where {A<:AbstractAgent}
  correct_pos_type(rand(1:nv(model)), model)
end

function remove_agent_from_space!(agent::A, model::ABM{A,<:DiscreteSpace}) where {A<:AbstractAgent}
    agentnode = coord2vertex(agent.pos, model)
    # remove from the space
    splice!(
        agent_positions(model)[agentnode],
        findfirst(a -> a == agent.id, agent_positions(model)[agentnode]),
    )
    return model
end

function move_agent!(agent::AbstractAgent, _pos::Integer, model::ABM{A,<:DiscreteSpace}) where {A}
    pos = correct_pos_type(_pos, model)
    # remove agent from old position
    if typeof(agent.pos) <: Tuple
        oldnode = coord2vertex(agent.pos, model)
        splice!(
            model.space.agent_positions[oldnode],
            findfirst(a -> a == agent.id, model.space.agent_positions[oldnode]),
        )
        agent.pos = vertex2coord(pos, model)  # update agent position
    else
        splice!(
            model.space.agent_positions[agent.pos],
            findfirst(a -> a == agent.id, model.space.agent_positions[agent.pos]),
        )
        agent.pos = pos
    end
    push!(model.space.agent_positions[pos], agent.id)
    return agent
end

function add_agent_to_space!(agent::A, model::ABM{A,<:DiscreteSpace}) where {A<:AbstractAgent}
    nn = coord2vertex(agent.pos, model)
    push!(model.space.agent_positions[nn], agent.id)
    return agent
end


#######################################################################################
# Extra space-related functions dedicated to discrete space
#######################################################################################
export add_agent_single!, move_agent_single!, fill_space!, move_agent_single!

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
    move_agent_single!(agent::AbstractAgent, model::ABM) → agent

Move agent to a random node while respecting a maximum of one agent
per node. If there are no empty nodes, the agent wont move.
Only valid for non-continuous spaces.
"""
function move_agent_single!(agent::AbstractAgent, model::ABM)
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

Returns the indices of empty nodes on the model space.
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
    get_node_contents(node, model)

Return the ids of agents in the `node` of the model's space (which
is an integer for `GraphSpace` and a tuple for `GridSpace`).
"""
get_node_contents(n::Integer, model::ABM{A,<:DiscreteSpace}) where {A} = agent_positions(model)[n]

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

"""
    space_neighbors(position, model::ABM, r) → ids

Return the ids of the agents neighboring the given `position` (which must match type
with the spatial structure of the `model`). `r` is the radius to search for agents.

For `DiscreteSpace` `r` must be integer and defines higher degree neighbors.
For example, for `r=2` include first and second degree neighbors,
that is, neighbors and neighbors of neighbors.
Specifically for `GraphSpace`, the keyword `neighbor_type` can also be used
as in [`node_neighbors`](@ref) to restrict search on directed graphs.

For `ContinuousSpace`, `r` is real number and finds all neighbors within distance `r`
(based on the space's metric).

    space_neighbors(agent::AbstractAgent, model::ABM [, r]) → ids

Call `space_neighbors(agent.pos, model, r)` but *exclude* the given
`agent` from the neighbors.
"""
function space_neighbors(agent::A, model::ABM{A,<:DiscreteSpace}, args...; kwargs...) where {A}
  all = space_neighbors(agent.pos, model, args...; kwargs...)
  d = findfirst(isequal(agent.id), all)
  d ≠ nothing && deleteat!(all, d)
  return all
end

function space_neighbors(pos, model::ABM{A, <: DiscreteSpace}, args...; kwargs...) where {A}
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
"""
    NodeIterator(model) → iterator

Create an iterator that returns node coordinates, if the space is a grid,
or otherwise node number, and the agent IDs in each node.
"""
struct NodeIterator{M<:ABM, S<:DiscreteSpace}
  model::M
  length::Int
end

NodeIterator(model::ABM{A,<:DiscreteSpace}) where {A} = NodeIterator(model, model.space)

function NodeIterator(m::M, s::S) where {M, S<:DiscreteSpace}
  L = LightGraphs.nv(s)
  return NodeIterator{M, S}(m, L)
end

Base.length(iter::NodeIterator) = iter.length

function Base.iterate(iter::NodeIterator{M,S}, state=1) where {M, S<:DiscreteSpace}
  state > iter.length && return nothing
  nodecontent = agent_positions(iter.model)[state]
  if S <: GridSpace
    node = vertex2coord(state, iter.model)
  else
    node = state
  end
  return ( (node, nodecontent), state+1 )
end

"""
    nodes(model; by = :id) -> ns
Return a vector of the node ids of the `model` that you can iterate over.
The `ns` are sorted depending on `by`:
* `:id` - just sorted by their number
* `:random` - randomly sorted
* `:population` - nodes are sorted depending on how many agents they accommodate.
  The more populated nodes are first.
"""
function nodes(model; by = :id)
    if by == :id
        return 1:nv(model)
    elseif by == :random
        return shuffle!(collect(1:nv(model)))
    elseif by == :population
        c = collect(1:nv(model))
        sort!(c, by = i -> length(get_node_contents(i, model)), rev = true)
        return c
    else
        error("unknown `by`.")
    end
end

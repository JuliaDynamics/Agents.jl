export Space, vertex2coords, coords2vertex, AbstractSpace,
find_empty_nodes, pick_empty, has_empty_nodes, get_node_contents,
id2agent, NodeIterator, node_neighbors, nodes
export nv, ne

#######################################################################################
# Basic space definition
#######################################################################################
LightGraphs.nv(space::AbstractSpace) = LightGraphs.nv(space.graph)
LightGraphs.ne(space::AbstractSpace) = LightGraphs.ne(space.graph)

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

struct GraphSpace{G} <: AbstractSpace
  graph::G
  agent_positions::Vector{Vector{Int}}
end
struct GridSpace{G, D, I<:Integer} <: AbstractSpace
  graph::G # Graph
  agent_positions::Vector{Vector{Int}}
  dimensions::NTuple{D, I}
end
function Base.show(io::IO, abm::AbstractSpace)
    s = "$(nameof(typeof(abm))) with $(nv(abm)) nodes and $(ne(abm)) edges"
    print(io, s)
end

Space(m::ABM) = m.space
agent_positions(m::ABM) = m.space.agent_positions
agent_positions(m::AbstractSpace) = m.agent_positions

"""
    isempty(node::Int, model::ABM)
Return `true` if there are no agents in `node`.
"""
Base.isempty(node::Integer, model::ABM) =
length(model.space.agent_positions[node]) == 0

"""
    Space(graph::AbstractGraph) -> GraphSpace
Create a space instance that is underlined by an arbitrary graph.
In this case, your agent positions (field `pos`) should be of type `Integer`.
"""
function Space(graph::G) where {G<:AbstractGraph}
  agent_positions = [Int[] for i in 1:LightGraphs.nv(graph)]
  return GraphSpace{G}(graph, agent_positions)
end

"""
    Space(dims::NTuple; periodic = false, moore = false) -> GridSpace
Create a space instance that represents a grid of dimensionality `length(dims)`,
with each dimension having the size of the corresponding entry of `dims`.
In this case, your agent positions (field `pos`) should be of type `NTuple{Int}`.

The two keyword arguments denote if the grid should be periodic on its ends,
and if the connections should be of type Moore or not (in the Moore case
the diagonal connections are also valid. E.g. for a 2D grid, each node has
8 neighbors).
"""
function Space(dims::NTuple{D, I}; periodic = false, moore = false) where {D, I}
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

vertex2coord(v::Tuple, args...) = v

#######################################################################################
# finding specific nodes or agents
#######################################################################################
"""
    find_empty_nodes(model::ABM)

Returns the IDs of empty nodes on the model space.
"""
function find_empty_nodes(model::ABM)
  ap = agent_positions(model)
  empty_nodes = [i for i in 1:length(ap) if length(ap[i]) == 0]
  return empty_nodes
end

"""
    pick_empty(model)

Return the ID of a random empty node or `0` if there are no empty nodes.
"""
function pick_empty(model)
  empty_nodes = find_empty_nodes(model)
  if length(empty_nodes) == 0
    return 0
  else
    random_node = rand(empty_nodes)
    return random_node
  end
end

"""
    has_empty_nodes(model)

Return true if there are empty nodes in the `model`.
"""
function has_empty_nodes(model)
  for el in agent_positions(model)
    length(el) != 0 && return true
  end
  return false
end

"""
    get_node_contents(n::Integer, model)

Return the ids of agents in the node `n` of the model.
"""
get_node_contents(n::Integer, model) = agent_positions(model)[n]

"""
    get_node_contents(agent::AbstractAgent, model)

Return all agents' ids in the same node as the `agent` (including the agent's own id).
"""
get_node_contents(agent::AbstractAgent, model) = get_node_contents(agent.pos, model)

"""
    get_node_contents(coords::Tuple, model)

Return the ids of agents in the node at `coords`.
"""
function get_node_contents(coords::Tuple, model)
  node_number = coord2vertex(coords, model)
  get_node_contents(node_number, model)
end

"""
    id2agent(id::Integer, model)

Return an agent given its ID.
"""
function id2agent(id::Integer, model::ABM)
  return model.agents[id]
end

"""
    node_neighbors(agent::AbstractAgent, model::ABM)
    node_neighbors(node::Int, model::ABM)

Return neighboring node coordinates/numbers of the node on which the agent resides.

If the model's space is `GraphSpace`, then the function will return node numbers.
If space is `GridSpace` then the neighbors are returned as coordinates (tuples).
"""
function node_neighbors(agent::AbstractAgent, model::ABM)
  if typeof(model.space) <: GraphSpace
    @assert agent.pos isa Integer
  elseif typeof(model.space) <: GridSpace
    @assert agent.pos isa Tuple
  end
  node_neighbors(agent.pos, model)
end

function node_neighbors(node_number::Integer, model::ABM)
  nn = neighbors(model.space.graph, node_number)
  return nn
end

function node_neighbors(node_coord::Tuple, model::ABM)
  node_number = coord2vertex(node_coord, model)
  nn = neighbors(model.space.graph, node_number)
  nc = [vertex2coord(i, model) for i in nn]
  return nc
end

"""
    node_neighbors(node_number::Integer, model::ABM, radius::Integer)

Returns a list of neighboring nodes to the node `node_number` within the `radius`.
"""
function node_neighbors(node_number::Integer, model::ABM, radius::Integer)
  neighbor_nodes = Set(node_neighbors(node_number, model))
  included_nodes = Set()
  for rad in 2:radius
    templist = Vector{Int}()
    for nn in neighbor_nodes
      if !in(nn, included_nodes)
        newns = node_neighbors(nn, model)
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
struct NodeIterator{M<:ABM, S}
  model::M
  length::Int
end

NodeIterator(model::ABM) = NodeIterator(model, model.space)

function NodeIterator(m::M, s::S) where {M, S}
  L = LightGraphs.nv(s)
  return NodeIterator{M, S}(m, L)
end

Base.length(iter::NodeIterator) = iter.length

function Base.iterate(iter::NodeIterator{M,S}, state=1) where {M, S}
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

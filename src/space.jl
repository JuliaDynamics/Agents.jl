#######################################################################################
# Basic space definition
#######################################################################################
abstract type AbstractSpace end
LightGraphs.nv(space::AbstractSpace) = LightGraphs.nv(space.graph)

struct GraphSpace{G} <: AbstractSpace
  graph::G
  agent_positions::Vector{Vector{Int}}
end
struct GridSpace{G, D, I<:Integer} <: AbstractSpace
  graph::G # Graph
  agent_positions::Vector{Vector{Int}}
  dimensions::NTuple{D, I}
end

"""
    space(graph::AbstractGraph) -> GraphSpace
Create a space instance that is underlined by an arbitrary graph.
"""
function space(graph::G) where {G<:AbstractGraph}
  agent_positions = [Int[] for i in 1:LightGraphs.nv(graph)]
  return GraphSpace{G}(graph, agent_positions)
end

"""
    space(dims::NTuple, periodic = false, moore = false) -> GridSpace
Create a space instance that represents a gird of dimensionality `size(dims)`,
with each dimension having the size of the corresponding entry of `dims`.
"""
function space(dims::NTuple{D, I}, periodic = false, moore = false) where {D, I}
  graph = _grid(dims..., periodic, moore)
  agent_positions = [Int[] for i in 1:LightGraphs.nv(graph)]
  return GridSpace{typeof(graph), D, I}(graph, agent_positions, dims)
end

# 1d grid
function _grid(length::Integer, periodic=false, moore = false)
  g = LightGraphs.path_graph(length)
  if periodic
    add_edge!(g, 1, length)
  end
  return g
end

# 2d grid
function _grid(x::Integer, y::Integer, periodic = false, moore = false)
  if moore
    g = _grid2d_moore(x, y, periodic)
  else
    g = LightGraphs.grid([x, y], periodic=periodic)
  end
  return g
end

function _grid2d_moore(xdim::Integer, ydim::Integer, periodic=false)
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
  @eval ($f)(c, model::AbstractModel) = ($f)(c, model.space)
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

coord2vertex(agent::AbstractAgent, model::AbstractModel) =
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

#######################################################################################
# finding specific nodes
#######################################################################################
"""
    find_empty_nodes_coords(model::AbstractModel)

Returns the coordinates of empty nodes on the model grid.
"""
function find_empty_nodes_coords(model::AbstractModel)
  empty_cells = find_empty_nodes(model::AbstractModel)
  empty_cells_coord = [vertex2coord(i, model) for i in empty_cells]
end

"""
    find_empty_nodes(model::AbstractModel)

Returns the IDs of empty nodes on the model space.
"""
function find_empty_nodes(model::AbstractModel)
  empty_cells = [i for i in 1:length(model.space.agent_positions) if length(model.space.agent_positions[i]) == 0]
  return empty_cells
end

"""
    pick_empty(model)

Returns the ID of a random empty cell. Returns 0 if there are no empty cells
"""
function pick_empty(model)
  empty_cells = find_empty_nodes(model)
  if length(empty_cells) == 0
    return 0
  else
    random_node = rand(empty_cells)
    return random_node
  end
end

"""

Returns true if the cell at `cell_id` is empty.
"""
function is_empty(cell_id::Integer, model::AbstractModel)
  if length(model.space.agent_positions[cell_id]) == 0
    return true
  else
    return false
  end
end

"""
    empty_nodes(model::AbstractArray)

Returns true if there are empty nodes, otherwise returns false.
"""
function empty_nodes(model::AbstractArray)
  ee = false
  for el in model.space.agent_positions
    if length(el) == 0
      return true
    end
  end
  return ee
end

"""
    get_node_contents(agent::AbstractAgent, model::AbstractModel)

Returns all agents' ids in the same node as the `agent`.
"""
function get_node_contents(agent::AbstractAgent, model::AbstractModel)
  get_node_contents(agent.pos, model)
end

"""
    get_node_contents(coords::Tuple, model::AbstractModel)

Returns the id of agents in the node at `coords`
"""
function get_node_contents(coords::Tuple, model::AbstractModel)
  node_number = coord2vertex(coords, model)
  get_node_contents(node_number, model)
end

"""
    get_node_contents(node_number::Integer, model::AbstractModel)

Returns the id of agents in the node at `node_number`
"""
function get_node_contents(node_number::Integer, model::AbstractModel)
  ns = model.space.agent_positions[node_number]
  return ns
end

"""
    id_to_agent(id::Integer, model::AbstractModel)

Returns an agent given its ID.
"""
function id_to_agent(id::Integer, model::AbstractModel)
  agent_index = findfirst(a-> a.id==id, model.agents)
  agent = model.agents[agent_index]
  return agent
end

"""
    node_neighbors(agent::AbstractAgent, model::AbstractModel)

Returns neighboring node coords/numbers of the node on which the agent resides. If agent `pos` is recorded an integer, the function will return node numbers of the neighbors. If the agent `pos` is a tuple, the function will return the coordinates of neighbors on a grid.
"""
function node_neighbors(agent::AbstractAgent, model::AbstractModel)
  node_neighbors(agent.pos, model)
end

"""
    node_neighbors(node_number::Integer, model::AbstractModel)

Returns neighboring node IDs of the node with `node_number`.
"""
function node_neighbors(node_number::Integer, model::AbstractModel)
  nn = neighbors(model.space.space, node_number)
  return nn
end

"""
    node_neighbors(node_coord::Tuple, model::AbstractModel)

Returns neighboring node coords of the node with `node_coord`.
"""
function node_neighbors(node_coord::Tuple, model::AbstractModel)
  node_number = coord2vertex(node_coord, model)
  nn = node_neighbors(node_number, model)
  nc = [vertex2coord(i, model) for i in nn]
  return nc
end

"""
    node_neighbors(node_number::Integer, model::AbstractModel, radius::Integer)

Returns a list of neighboring cells to the node `node_number` within the `radius`.
"""
function node_neighbors(node_number::Integer, model::AbstractModel, radius::Integer)
  neighbor_cells = Set(node_neighbors(node_number, model))
  included_cells = Set()
  for rad in 2:radius
    templist = Array{Integer}(undef, 0)
    for nn in neighbor_cells
      if !in(nn, included_cells)
        newns = node_neighbors(nn, model)
        for newn in newns
          push!(templist, newn)
        end
      end
    end
    for tt in templist
      push!(neighbor_cells, tt)
    end
  end
  nlist = collect(neighbor_cells)
  j = findfirst(a-> a==node_number, nlist)
  if j != nothing
    splice!(nlist, j)
  end
  return nlist
end

"""
    Node_iter(model::AbstractModel)

An iterator that returns node coordinates, if the graph is a grid, or otherwise node numbers, and the agents in each node.
"""
struct Node_iter
  model::AbstractModel
  length::Integer
  postype::DataType
end

Node_iter(model::AbstractModel) = Node_iter(model, length(model.space.agent_positions), typeof(model.agents[1].pos))

Base.length(iter::Node_iter) = iter.length

function Base.iterate(iter::Node_iter, state=1)
  if state > iter.length
      return nothing
  end

  cellcontent = iter.model.space.agent_positions[state]
  nagents = length(cellcontent)
  if nagents == 0
    element = (Integer[], Array{AbstractArray}(undef,0))
  else
    if iter.postype <: Tuple
      pp = vertex2coord(state, iter.model)
      agentlist = Array{AbstractAgent}(undef, nagents)
      for n in 1:nagents
        agentlist[n] = id_to_agent(cellcontent[n], iter.model)
      end
      element = (pp, agentlist)
    else
      pp = state
      agentlist = Array{AbstractAgent}(undef, nagents)
      for n in 1:nagents
        agentlist[n] = id_to_agent(cellcontent[n], iter.model)
      end
      element = (pp, agentlist)
    end
  end

  return (element, state+1)
end

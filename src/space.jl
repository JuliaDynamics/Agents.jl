# A grid can be 0D (a node), 1D (a line of nodes), 2D (a surface of nodes) or 3D (a surface of nodes with values at each node).

"""
An abstract space type. Your grid type should have the following fields: `dimensions` (Tuple{Integer, Integer, Integer}), agent_positions (Array{Array{Integer}}), and `grid`.

`agent_positions` should always be a list of lists that accept `Integers`, i.e. agent ids.
"""
abstract type AbstractSpace end


function grid0D()
end

"""
A path graph. A 1D grid that can optionally be toroidal (a ring).
"""
function grid1D(length::Integer; periodic=false)
  g = PathGraph(length)
  if periodic
    add_edge!(g, 1, length)
  end
  return g
end

"""
A regular 2D grid where each node is at most connected to four neighbors. It can optionally be toroidal.
"""
function grid2D(x::Integer, y::Integer; periodic=false)
  g = Grid([x, y], periodic=periodic)
end

"""
A regular 3D grid where each node is at most connected to 6 neighbors. It can optionally be toroidal.
"""
function grid3D(x::Integer, y::Integer, z::Integer; periodic=false, triangular=false)
  if periodic
    if triangular
      g = grid2D_triangles(x, y, periodic=true)
    else
      g = grid2D(x, y, periodic=true)
    end
  else
    if triangular
      g = grid2D_triangles(x, y, periodic=false)
    else
      g = grid2D(x, y)
    end
  end
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

"""
A regular 2D grid where each node is at most connected to eight neighbors. It can optionally be toroidal
"""
function grid2D_triangles(xdim::Integer, ydim::Integer; periodic=false)
  g = Grid([xdim, ydim], periodic=periodic)
  for x in 1:xdim
    for y in 1:ydim
      nodeid = coord_to_vertex((x, y), (xdim, ydim))
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
        add_edge!(g, nodeid, coord_to_vertex((pp[1], pp[2]), (xdim, ydim)))
      end
    end
  end
  return g
end

"""
    grid(x::Integer, y::Integer, z::Integer, periodic=false, triangle=false)

Return a grid based on its dimensions. `x`, `y`, and `z` are the dimensions of the grid. If all dimensions are 1, it will return a 0D space, where all agents are in the same position. If `x` is more than 1, but `y` and `z` are 1, it will return a 1D grid. If `x` and `y` are more than 1, and `z=1`, it will return a 2D regular grid.

* `periodic=true` will create toroidal grids.
* `triangle=true` works when the dimensions of the grid are 2D. It will return a regular grid in which each node is at most connected to eight neighbors. If `false`, each node will be at most connected to four neighbors.
"""
function grid(x::Integer, y::Integer, z::Integer, periodic::Bool=false, triangle::Bool=false)
  if x < 1 || y < 1 || z < 1
    throw("x, y, z each can be minimum 1.")
  end
  if x ==1 && y == 1 && z == 1
    g = grid0D()
  elseif x > 1 && y == 1 && z == 1
    g = grid1D(x, periodic=periodic)
  elseif x > 1 && y > 1 && z == 1
    g = grid(x, y, periodic, triangle)
  elseif x > 1 && y > 1 && z > 1
    g = grid3D(x, y, z)
  else
    throw("Invalid grid dimensions! If only one dimension is 1, it should be `z`, if two dimensions are 1, they should be `y` and `z`.")
  end
  return g
end

function grid(x::Integer, y::Integer, periodic::Bool=false, triangle::Bool=false)
  if triangle
    g = grid2D_triangles(x, y, periodic=periodic)
  else
    g = grid2D(x, y, periodic=periodic)
  end
  return g
end

"""
    grid(dims::Tuple{Integer, Integer, Integer}, periodic=false, triangle=false)

Return a grid based on its dimensions. `x`, `y`, and `z` are the dimensions of the grid. If all dimensions are 1, it will return a 0D space, where all agents are in the same position. If `x` is more than 1, but `y` and `z` are 1, it will return a 1D grid. If `x` and `y` are more than 1, and `z=1`, it will return a 2D regular grid.

* `periodic=true` will create toroidal grids.
* `triangle=true` will return a regular grid in which each node is at most connected to eight neighbors in one plane. If `false`, each node will be at most connected to four neighbors.
"""
function grid(dims::Tuple{Integer, Integer, Integer}, periodic::Bool=false, triangle::Bool=false)
  grid(dims[1], dims[2], dims[3], periodic, triangle)
end

"""
    grid(dims::Tuple{Integer, Integer}, periodic=false, triangle=false)

Return a grid based on its dimensions. `x`, `y` are the dimensions of the grid. If all dimensions are 1, it will return a 0D space, where all agents are in the same position. If `x` is more than 1, but `y` is 1, it will return a 1D grid.

* `periodic=true` will create toroidal grids.
* `triangle=true` will return a regular grid in which each node is at most connected to eight neighbors in one plane. If `false`, each node will be at most connected to four neighbors.
"""
function grid(dims::Tuple{Integer,Integer}, periodic::Bool=false, triangle::Bool=false)
  grid(dims[1], dims[2], periodic, triangle)
end

"""
    gridsize(dims::Tuple{Integer, Integer, Integer})

Returns the size of a grid with dimenstions `dims`.
"""
function gridsize(dims::Tuple{Integer, Integer, Integer})
  dims[1] * dims[2] * dims[3]
end

"""
    gridsize(dims::Tuple{Integer, Integer})

Returns the size of a grid with dimenstions `dims`.
"""
function gridsize(dims::Tuple{Integer, Integer})
  dims[1] * dims[2]
end

function gridsize(x::Integer, y::Integer, z::Integer)
  gridsize((x,y,z))
end

"""
    move_agent!(agent::AbstractAgent, pos::Tuple, model::AbstractModel)
  
Adds `agentID` to a new position in the grid and removes it from the old position. Also updates the agent to represent the new position. `pos` is tuple of x, y, z (only if its a 3D space) coordinates of the grid node. If `pos` is not given, the agent is moved to a random position on the grid. 
"""
function move_agent!(agent::AbstractAgent, pos::Tuple, model::AbstractModel)
  # node number from x, y, z coordinates
  nodenumber = coord_to_vertex(pos, model)
  move_agent!(agent, nodenumber, model)
end

"""
    move_agent!(agent::AbstractAgent, pos::Integer, model::AbstractModel)

Adds `agentID` to a new position in the grid and removes it from the old position. Also updates the agent to represent the new position. `pos` is an integer showing the number of the node on the grid node. If `pos` is not given, the agent is moved to a random position on the grid.
"""
function move_agent!(agent::AbstractAgent, pos::Integer, model::AbstractModel)
  push!(model.space.agent_positions[pos], agent.id)
  # remove agent from old position
  if typeof(agent.pos) <: Tuple
    oldnode = coord_to_vertex(agent.pos, model)
    splice!(model.space.agent_positions[oldnode], findfirst(a->a==agent.id, model.space.agent_positions[oldnode]))
    agent.pos = vertex_to_coord(pos, model)  # update agent position
  else
    splice!(model.space.agent_positions[pos], findfirst(a->a==agent.id, model.space.agent_positions[pos]))
    agent.pos = pos
  end
end

function move_agent!(agent::AbstractAgent, model::AbstractModel)
  nodenumber = rand(1:nv(model.space.space))
  move_agent!(agent, nodenumber, model)
  return agent.pos
end

"""
    move_agent_single!(agent::AbstractAgent, model::AbstractModel)

Moves agent to a random nodes on the grid while respecting a maximum of one agent per node. If there are no empty nodes, the agent wont move.

Return the agent's new position.
"""
function move_agent_single!(agent::AbstractAgent, model::AbstractModel)
  empty_cells = [i for i in 1:length(model.space.agent_positions) if length(model.space.agent_positions[i]) == 0]
  if length(empty_cells) > 0
    random_node = rand(empty_cells)
    move_agent!(agent, random_node, model)
  end
  return agent.pos
end

"""
    add_agent!(agent::AbstractAgent, pos::Tuple{Integer, Integer, Integer}, model::AbstractModel)

Adds the agent to the `pos` in the space and to the list of agents. `pos` is tuple of x, y, and z (only if its a 3D space) coordinates of the grid node. If `pos` is not given, the agent is added to a random position.

This function is for positioning agents on the grid for the first time.
"""
function add_agent!(agent::AbstractAgent, pos::Tuple, model::AbstractModel)
  # node number from x, y, z coordinates
  nodenumber = coord_to_vertex(pos, model)
  add_agent!(agent, nodenumber, model)
end

"""
    add_agent!(agent::AbstractAgent, pos::Integer, model::AbstractModel)

Adds the agent to the `pos` in the space and to the list of agents. `pos` is the node number of the space. If `pos` is not given, the agent is added to a random position.

This function is for positioning agents on the grid for the first time.
"""
function add_agent!(agent::AbstractAgent, pos::Integer, model::AbstractModel)
  push!(model.space.agent_positions[pos], agent.id)
  push!(model.agents, agent)
  if typeof(agent.pos) == Integer
    agent.pos = pos
  elseif typeof(agent.pos) <: Tuple
    agent.pos = vertex_to_coord(pos, model)  # update agent position
  else
    throw("Unknown type of agent.pos.")
  end
end

"""
    add_agent!(agent::AbstractAgent, model::AbstractModel)
Adds agent to a random node in the space and to the agent to the list of agents. 

Returns the agent's new position.
"""
function add_agent!(agent::AbstractAgent, model::AbstractModel)
  agentID = agent.id
  nodenumber = rand(1:nv(model.space.space))
  add_agent!(agent, nodenumber, model)
  return agent.pos
end

"""
    add_agent_single!(agent::AbstractAgent, model::AbstractModel)

Adds agent to a random node in the space while respecting a maximum one agent per node. It does not do anything if there are no empty nodes.

Returns the agent's new position.
"""
function add_agent_single!(agent::AbstractAgent, model::AbstractModel)
  empty_cells = [i for i in 1:length(model.space.agent_positions) if length(model.space.agent_positions[i]) == 0]
  if length(empty_cells) > 0
    random_node = rand(empty_cells)
    add_agent!(agent, random_node, model)
  end
  return agent.pos
end

"""
    find_empty_nodes_coords(model::AbstractModel)

Returns the coordinates of empty nodes on the model grid.
"""
function find_empty_nodes_coords(model::AbstractModel)
  empty_cells = find_empty_nodes(model::AbstractModel)
  empty_cells_coord = [vertex_to_coord(i, model) for i in empty_cells]
end

"""
    find_empty_nodes(model::AbstractModel)

Returns the numbers of empty nodes on the model space.
"""
function find_empty_nodes(model::AbstractModel)
  empty_cells = [i for i in 1:length(model.space.agent_positions) if length(model.space.agent_positions[i]) == 0]
  return empty_cells
end

"""
    coord_to_vertex(coord::Tuple{Integer, Integer, Integer}, model::AbstractModel)

Returns the node number from x, y, z coordinates.
"""
function coord_to_vertex(coord::Tuple, model::AbstractModel)
  dims = model.space.dimensions
  coord_to_vertex(coord, dims)
end

function coord_to_vertex(agent::AbstractAgent, model::AbstractModel)
  coord_to_vertex(agent.pos, model)
end

function coord_to_vertex(x::Integer, y::Integer, z::Integer, model::AbstractModel)
  coord_to_vertex((x,y,z), model)
end

function coord_to_vertex(x::Integer, y::Integer, model::AbstractModel)
  coord_to_vertex((x,y), model)
end

function coord_to_vertex(x::Integer, y::Integer, z::Integer,dims::Tuple{Integer, Integer, Integer})
  coord_to_vertex((x,y,z), dims)
end

function coord_to_vertex(x::Integer, y::Integer,dims::Tuple{Integer, Integer})
  coord_to_vertex((x,y), dims)
end

"""
    coord_to_vertex(coord::Tuple{Integer, Integer, Integer}, dims::Tuple{Integer, Integer, Integer})

Returns node number from x, y, z coordinates.
"""
function coord_to_vertex(coord::Tuple{Integer, Integer, Integer}, dims::Tuple{Integer, Integer, Integer})
  if dims[1] > 1 && dims[2] == 1 && dims[3] == 1  # 1D grid
    nodeid = coord[1]
  elseif dims[1] > 1 && dims[2] > 1 && dims[3] == 1  # 2D grid
    nodeid = coord_to_vertex((coord[1], coord[2]), (dims[1], dims[2]))
  else # 3D grid
    nodeid = (coord[2] * dims[1]) - (dims[1] - coord[1])  # (y * xlength) - (xlength - x)
    nodeid = nodeid + ((dims[1]*dims[2]) * (coord[3]-1))
  end
  return nodeid
end

function coord_to_vertex(coord::Tuple{Integer,Integer}, dims::Tuple{Integer,Integer})
  nodeid = (coord[2] * dims[1]) - (dims[1] - coord[1])  # (y * xlength) - (xlength - x)
  return nodeid
end

"""
    vertex_to_coord(vertex::Integer, model::AbstractModel)

Returns the coordinates of a node given its number on the graph.
"""
function vertex_to_coord(vertex::Integer, model::AbstractModel)
  dims = model.space.dimensions
  vertex_to_coord(vertex, dims)
end

"""
    vertex_to_coord(vertex::Integer, dims::Tuple{Integer, Integer, Integer})

Returns the coordinates of a node given its number on a 3D grid.
"""
function vertex_to_coord(vertex::Integer, dims::Tuple{Integer, Integer, Integer})
  if dims[1] > 1 && dims[2] == 1 && dims[3] == 1  # 1D grid
    coord = (vertex, 1)
  elseif dims[1] > 1 && dims[2] > 1 && dims[3] == 1  # 2D grid
    coord = vertex_to_coord(vertex::Integer, (dims[1], dims[2]))
    coord = (coord[1], coord[2], 1)
  elseif dims[1] > 1 && dims[2] > 1 && dims[3] > 1  # 3D grid
    gridbasesize = dims[1]*dims[2]
    zcoord = ceil(Integer, vertex/gridbasesize)
    vertex2d = vertex - ((zcoord-1) * gridbasesize)
    coord2d = vertex_to_coord(vertex2d, (dims[1], dims[2]))
    coord = (coord2d[1], coord2d[2], zcoord)
  else
    error("Wrong coords!")
  end
  return coord
end

"""
    vertex_to_coord(vertex::Integer, dims::Tuple{Integer,Integer})

Returns the coordinates of a node given its number on a 2D grid.
"""
function vertex_to_coord(vertex::Integer, dims::Tuple{Integer,Integer})
  x = vertex % dims[1]
  if x == 0
    x = dims[1]
  end
  y = ceil(Integer, vertex/dims[1])
  coord = (x, y)
  return coord
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
  node_number = coord_to_vertex(coords, model)
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

Returns neighboring node numbers of the node with `node_number`.
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
  node_number = coord_to_vertex(node_coord, model)
  nn = node_neighbors(node_number, model)
  nc = [vertex_to_coord(i, model) for i in nn]
  return nc
end


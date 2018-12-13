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

function grid3D()
  #TODO
  throw("3D grids are not implemented yet!")
end

"""
A regular 2D grid where each node is at most connected to eight neighbors. It can optionally be toroidal
"""
function grid2D_triangles(xdim::Integer, ydim::Integer; periodic=false)
  g = Grid([xdim, ydim], periodic=periodic)
  for x in 1:xdim
    for y in 1:ydim
      nodeid = coord_to_vertex((x, y, 1), (xdim, ydim, 1))
      connect_to = []
      if y == ydim
        if x == 1
          if periodic
            tp = (xdim, 1, 1); push!(connect_to, tp)
            tp = (2, ydim-1, 1); push!(connect_to, tp)
          else
            tp = (2, ydim-1, 1); push!(connect_to, tp)
          end
        elseif x == xdim
          if periodic
            tp = (1, 1, 1); push!(connect_to, tp)
            tp = (xdim-1, ydim-1, 1); push!(connect_to, tp)
          else
            tp = (xdim-1, ydim-1, 1); push!(connect_to, tp)
          end
        else
          if periodic
            tp = (x-1, 1, 1); push!(connect_to, tp)
            tp = (x+1, 1, 1); push!(connect_to, tp)
            tp = (x-1, y-1, 1); push!(connect_to, tp)
            tp = (x+1, y-1, 1); push!(connect_to, tp)
          else
            tp = (x-1, y-1, 1); push!(connect_to, tp)
            tp = (x+1, y-1, 1); push!(connect_to, tp)
          end
        end
      elseif y == 1
        if x == 1
          if periodic
            tp = (xdim, ydim, 1); push!(connect_to, tp)
            tp = (2, y+1, 1); push!(connect_to, tp)
          else
            tp = (2, y+1, 1); push!(connect_to, tp)
          end
        elseif x == xdim
          if periodic
            tp = (1, y, 1); push!(connect_to, tp)
            tp = (xdim-1, y+1, 1); push!(connect_to, tp)
          else
            tp = (xdim-1, y+1, 1); push!(connect_to, tp)
          end
        else
          if periodic
            tp = (x-1, y+1, 1); push!(connect_to, tp)
            tp = (x+1, y+1, 1); push!(connect_to, tp)
            tp = (x-1, ydim, 1); push!(connect_to, tp)
            tp = (x+1, ydim, 1); push!(connect_to, tp)
          else
            tp = (x-1, y+1, 1); push!(connect_to, tp)
            tp = (x+1, y+1, 1); push!(connect_to, tp)
          end
        end
      elseif y != 1 && y != ydim && x == 1
        if periodic
          tp = (x+1, y+1, 1); push!(connect_to, tp)
          tp = (x+1, y-1, 1); push!(connect_to, tp)
          tp = (xdim, y+1, 1); push!(connect_to, tp)
          tp = (xdim, y-1, 1); push!(connect_to, tp)
        else
          tp = (x+1, y+1, 1); push!(connect_to, tp)
          tp = (x+1, y-1, 1); push!(connect_to, tp)
        end       
      elseif y != 1 && y != ydim && x == xdim
        if periodic
          tp = (x-1, y+1, 1); push!(connect_to, tp)
          tp = (x-1, y-1, 1); push!(connect_to, tp)
          tp = (1, y+1, 1); push!(connect_to, tp)
          tp = (1, y-1, 1); push!(connect_to, tp)
        else
          tp = (x-1, y+1, 1); push!(connect_to, tp)
          tp = (x-1, y-1, 1); push!(connect_to, tp)
        end  
      else
          tp = (x+1, y+1, 1); push!(connect_to, tp)
          tp = (x-1, y-1, 1); push!(connect_to, tp)
          tp = (x+1, y-1, 1); push!(connect_to, tp)
          tp = (x-1, y+1, 1); push!(connect_to, tp)             
      end

      for pp in connect_to
        add_edge!(g, nodeid, coord_to_vertex((pp[1], pp[2], 1), (xdim, ydim, 1)))
      end
    end
  end
  return g
end

"""
    grid(x::Integer, y::Integer, z::Integer, periodic=false, triangle=false)

Return a grid based on its dimensions. `x`, `y`, and `z` are the dimensions of the grid. If all dimensions are 1, it will return a 0D space, where all agents are in the same position. If `x` is more than 1, but `y` and `z` are 1, it will return a 1D grid. If `x` and `y` are more than 1, and `z=1`, it will return a 2D regular grid. 3D grids are not implemented yet.

* `periodic=true` will create toroidal grids.
* `triangle=true` works when the dimensions of the grid are 2D. It will return a regular grid in which each node is at most connected to eight neighbors. If `false`, each node will be at most connected to four neighbors.
"""
function grid(x::Integer, y::Integer, z::Integer, periodic=false, triangle=false)
  if x < 1 || y < 1 || z < 1
    throw("x, y, or z can be minimum 1!")
  end
  if x ==1 && y == 1 && z == 1
    g = grid0D()
  elseif x > 1 && y == 1 && z == 1
    g = grid1D(x, periodic=periodic)
  elseif x > 1 && y > 1 && z == 1
    if triangle
      g = grid2D_triangles(x, y, periodic=periodic)
    else
      g = grid2D(x, y, periodic=periodic)
    end
  elseif x > 1 && y > 1 && z > 1
    g = grid3D(x, y, z)
  else
    throw("Invalid grid dimensions! If only one dimension is 1, it should be `z`, if two dimensions are 1, they should be `y` and `z`.")
  end
  return g
end

"""
    grid(dims::Tuple{Integer, Integer, Integer}, periodic=false, triangle=false)

Return a grid based on its dimensions. `x`, `y`, and `z` are the dimensions of the grid. If all dimensions are 1, it will return a 0D space, where all agents are in the same position. If `x` is more than 1, but `y` and `z` are 1, it will return a 1D grid. If `x` and `y` are more than 1, and `z=1`, it will return a 2D regular grid. 3D grids are not implemented yet.

* `periodic=true` will create toroidal grids.
* `triangle=true` works when the dimensions of the grid are 2D. It will return a regular grid in which each node is at most connected to eight neighbors. If `false`, each node will be at most connected to four neighbors.
"""
function grid(dims::Tuple{Integer, Integer, Integer}, periodic=false, triangle=false)
  grid(dims[1], dims[2], dims[3], periodic, triangle)
end

"""
    gridsize(dims::Tuple{Integer, Integer, Integer})

Returns the size of a grid with dimenstions `dims`.
"""
function gridsize(dims::Tuple{Integer, Integer, Integer})
  dims[1] * dims[2] * dims[3]
end

function gridsize(x::Integer, y::Integer, z::Integer)
  gridsize((x,y,z))
end


"""
    move_agent_on_grid!(agent::AbstractAgent, pos::Tuple{Integer, Integer, Integer}, model::AbstractModel)
  
Adds `agentID` to a new position in the grid and removes it from the old position. Also updates the agent to represent the new position. `pos` is tuple of x, y, z coordinates of the grid node. If `pos` is not given, the agent is moved to a random position on the grid. 
"""
function move_agent_on_grid!(agent::AbstractAgent, pos::Tuple{Integer, Integer, Integer}, model::AbstractModel)
  agentID = agent.id
  # node number from x, y, z coordinates
  nodenumber = coord_to_vertex(pos, model)
  push!(model.space.agent_positions[nodenumber], agentID)
  # remove agent from old position
  oldnode = coord_to_vertex(agent.pos, model)
  splice!(model.space.agent_positions[oldnode], findfirst(a->a==agent.id, model.space.agent_positions[oldnode]))
  agent.pos = pos  # update agent position
end

"""
    move_agent_on_grid!(agent::AbstractAgent, pos::Integer, model::AbstractModel)

Adds `agentID` to a new position in the grid and removes it from the old position. Also updates the agent to represent the new position. `pos` is an integer showing the number of the node on the grid node. If `pos` is not given, the agent is moved to a random position on the grid.
"""
function move_agent_on_grid!(agent::AbstractAgent, pos::Integer, model::AbstractModel)
  agentID = agent.id
  nodenumber = pos
  push!(model.space.agent_positions[nodenumber], agentID)
  # remove agent from old position
  oldnode = coord_to_vertex(agent.pos, model)
  splice!(model.space.agent_positions[oldnode], findfirst(a->a==agent.id, model.space.agent_positions[oldnode]))
  agent.pos = vertex_to_coord(pos, model)  # update agent position
end

function move_agent_on_grid!(agent::AbstractAgent, model::AbstractModel)
  agentID = agent.id
  nodenumber = rand(1:nv(model.space.space))
  push!(model.space.agent_positions[nodenumber], agentID)
  # remove agent from old position
  oldnode = coord_to_vertex(agent.pos, model)
  splice!(model.space.agent_positions[oldnode], findfirst(a->a==agent.id, model.space.agent_positions[oldnode]))
  agent.pos = vertex_to_coord(nodenumber, model) # update agent position
  return agent.pos
end

"""
    add_agent_to_grid!(agent::AbstractAgent, pos::Tuple{Integer, Integer, Integer}, model::AbstractModel)

Add `agentID` to a position on the grid. `pos` is tuple of x, y, z coordinates of the grid node. If `pos` is not given, the agent is added to a random position.

This function is for positioning agents on the grid for the first time.
"""
function add_agent_to_grid!(agent::AbstractAgent, pos::Tuple{Integer, Integer, Integer}, model::AbstractModel)
  agentID = agent.id
  # node number from x, y, z coordinates
  nodenumber = coord_to_vertex(pos, model)
  push!(model.space.agent_positions[nodenumber], agentID)
  agent.pos = pos  # update agent position
  return agent.pos
end

"""
    add_agent_to_grid!(agent::AbstractAgent, pos::Integer, model::AbstractModel)

Add `agentID` to a position in the grid. `pos` is the node number of the grid. If `pos` is not given, the agent is added to a random position.

This function is for positioning agents on the grid for the first time.
"""
function add_agent_to_grid!(agent::AbstractAgent, pos::Integer, model::AbstractModel)
  push!(model.space.agent_positions[pos], agent.id)
  agent.pos = vertex_to_coord(pos, model)  # update agent position
end

function add_agent_to_grid!(agent::AbstractAgent, model::AbstractModel)
  agentID = agent.id
  nodenumber = rand(1:nv(model.space.space))
  push!(model.space.agent_positions[nodenumber], agentID)
  agent.pos = vertex_to_coord(nodenumber, model) # update agent position
end

"""
    move_agent_on_grid_single!(agent::AbstractAgent, model::AbstractModel)

Moves agent to a random nodes on the grid while respecting a maximum of one agent per node.
"""
function move_agent_on_grid_single!(agent::AbstractAgent, model::AbstractModel)
  empty_cells = [i for i in 1:length(model.space.agent_positions) if length(model.space.agent_positions[i]) == 0]
  random_node = rand(empty_cells)
  move_agent_on_grid!(agent, random_node, model)
end

"""
    find_empty_nodes(model::AbstractModel)

Returns the coordinates of empty nodes on the model grid.
"""
function find_empty_nodes(model::AbstractModel)
  empty_cells = [i for i in 1:length(model.space.agent_positions) if length(model.space.agent_positions[i]) == 0]
  empty_cells_coord = [vertex_to_coord(i, model) for i in empty_cells]
end

"""
    add_agent_to_grid_single!(agent::AbstractAgent, model::AbstractModel)

Adds agent to a random node on the grid while respecting a maximum one agent per node.
"""
function add_agent_to_grid_single!(agent::AbstractAgent, model::AbstractModel)
  empty_cells = [i for i in 1:length(model.space.agent_positions) if length(model.space.agent_positions[i]) == 0]
  random_node = rand(empty_cells)
  add_agent_to_grid!(agent, vertex_to_coord(random_node, model), model)
end

"""
    coord_to_vertex(coord::Tuple{Integer, Integer, Integer}, model::AbstractModel)

Returns the node number from x, y, z coordinates.
"""
function coord_to_vertex(coord::Tuple{Integer, Integer, Integer}, model::AbstractModel)
  dims = model.space.dimensions
  coord_to_vertex(coord, dims)
end

function coord_to_vertex(x::Integer, y::Integer, z::Integer, model::AbstractModel)
  coord_to_vertex((x,y,z), model)
end

function coord_to_vertex(x::Integer, y::Integer, z::Integer,dims::Tuple{Integer, Integer, Integer})
  coord_to_vertex((x,y,z), dims)
end


"""
    coord_to_vertex(coord::Tuple{Integer, Integer, Integer}, dims::Tuple{Integer, Integer, Integer})

Returns node number from x, y, z coordinates.
"""
function coord_to_vertex(coord::Tuple{Integer, Integer, Integer}, dims::Tuple{Integer, Integer, Integer})
  if dims[1] > 1 && dims[2] == 1 && dims[3] == 1  # 1D grid
    nodeid = coord[1]
  elseif dims[1] > 1 && dims[2] > 1 && dims[3] == 1  # 2D grid
    nodeid = (coord[2] * dims[1]) - (dims[1] - coord[1])  # (y * xlength) - (xlength - x)
  else # 3D grid
    #TODO
  end
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

Returns the coordinates of a node given its number on the graph.
"""
function vertex_to_coord(vertex::Integer, dims::Tuple{Integer, Integer, Integer})
  if dims[1] > 1 && dims[2] == 1 && dims[3] == 1  # 1D grid
    coord = (vertex, 1, 1)
  elseif dims[1] > 1 && dims[2] > 1 && dims[3] == 1  # 2D grid
    x = vertex % dims[1]
    if x == 0
      x = dims[1]
    end
    y = ceil(Integer, vertex/dims[1])
    coord = (x, y, 1)
  else # 3D grid
    #TODO
  end
  return coord
end

"""
    get_node_contents(agent::AbstractAgent, model::AbstractModel)
  
Returns all agents' ids in the same node as the `agent`.
"""
function get_node_contents(agent::AbstractAgent, model::AbstractModel)
  agent_node = coord_to_vertex(agent.pos, model)
  ns = model.space.agent_positions[agent_node]
end

"""
    get_node_contents(coords::Tuple, model::AbstractModel)

Returns the id of agents in the node at `coords`
"""
function get_node_contents(coords::Tuple, model::AbstractModel)
  node_number = coord_to_vertex(coords, model)
  ns = model.space.agent_positions[node_number]
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

Returns neighboring node coords of the node on which the agent resides.
"""
function node_neighbors(agent::AbstractAgent, model::AbstractModel)
  agent_node = coord_to_vertex(agent.pos, model)
  nn = neighbors(model.space.space, agent_node)
  nc = [vertex_to_coord(i, model) for i in nn]
end


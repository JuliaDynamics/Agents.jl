# A grid can be 0D (a node), 1D (a line of nodes), 2D (a surface of nodes) or 3D (a surface of nodes with values at each node).

"""
An abstract grid type. Your grid type should have the following fields: `dimensions` (Tuple{Integer, Integer, Integer}), agent_positions (Array{Array{Integer}}), and `grid`.
"""
abstract type AbstractGrid end

function grid0D() <: AbstractSpace
end

function grid1D(length::Integer; periodic=false)
  if periodic
    g = PathGraph(length)
    add_edge!(g, 1, length)
  else
    g = PathGraph(length)
  end
end

function grid2D(n::Integer, m::Integer; periodic=false)
  g = Grid([n, m], periodic=periodic)
end

function grid3D()
  #TODO
  throw("3D grids are not implemented yet!")
end

"""
    grid(x::Ingeter, y::Integer, z::Integer)

Return a grid based on its size.
"""
function grid(x::Integer, y::Integer, z::Integer; periodic=false)
  if x < 1 || y < 1 || z < 1
    throw("x, y, or z can be minimum 1!")
  end
  if x + y + z == 1
    g = grid0D()
  elseif x > 1 && y == 1 && z == 1
    g = grid1D(x, periodic=periodic)
  elseif x > 1 && y > 1 && z == 1
    g = grid2D(x, y, periodic=periodic)
  elseif x > 1 && y > 1 && z > 1
    g = grid3D(x, y, z)
  else
    throw("Invalid grid dimensions! If only one dimension is 1, it should be `z`, if two dimensions are 1, they should be `y` and `z`.")
  end
  return g
end

function grid(dims::Tuple{Integer, Integer, Integer})
  grid(dims[1], dims[2], dims[3])
end

function gridsize(dims::Tuple{Integer, Integer, Integer})
  dims[1] * dims[2] * dims[3]
end

# function empty_pos_container(model::AbstractModel)
#   container = Array{Array{AbstractAgent}}(undef, )
# end

"""
Add `agentID` to a position in the grid. `pos` is tuple of x, y, z coordinates of the grid node. if `pos` is not given, the agent is added to a random position 
"""
function move_agent_on_grid!(agent::AbstractAgent, pos::Tuple{Integer, Integer, Integer}, model::AbstractModel)
  agentID = agent.id
  # node number from x, y, z coordinates
  nodenumber = coord_to_vertex(pos, model)
  push!(model.grid.agent_positions[nodenumber], agentID)
  # remove agent from old position
  oldnode = coord_to_vertex(agent.pos, model)
  splice!(model.grid.agent_positions[oldnode], findfirst(a->a==agent.id, model.grid.agent_positions[oldnode]))
  agent.pos = pos  # update agent position
end

function move_agent_on_grid!(agent::AbstractAgent, model::AbstractModel)
  agentID = agent.id
  nodenumber = rand(1:nv(model.grid.grid))
  push!(model.grid.agent_positions[nodenumber], agentID)
  # remove agent from old position
  oldnode = coord_to_vertex(agent.pos, model)
  splice!(model.grid.agent_positions[oldnode], findfirst(a->a==agent.id, model.grid.agent_positions[oldnode]))
  agent.pos = vertex_to_coord(nodenumber, model) # update agent position
end

"""
Add `agentID` to a position in the grid. `pos` is tuple of x, y, z coordinates of the grid node. if `pos` is not given, the agent is added to a random position 
"""
function add_agent_to_grid!(agent::AbstractAgent, pos::Tuple{Integer, Integer, Integer}, model::AbstractModel)
  agentID = agent.id
  # node number from x, y, z coordinates
  nodenumber = coord_to_vertex(pos, model)
  push!(model.grid.agent_positions[nodenumber], agentID)
  agent.pos = pos  # update agent position
end

function add_agent_to_grid!(agent::AbstractAgent, model::AbstractModel)
  agentID = agent.id
  nodenumber = rand(1:nv(model.grid.grid))
  push!(model.grid.agent_positions[nodenumber], agentID)
  agent.pos = vertex_to_coord(nodenumber, model) # update agent position
end

"""
get node number from x, y, z coordinates
"""
function coord_to_vertex(coord::Tuple{Integer, Integer, Integer}, model::AbstractModel)
  dims = model.grid.dimensions
  if dims[1] > 1 && dims[2] == 1 && dims[3] == 1  # 1D grid
    nodeid = coord[1]
  elseif dims[1] > 1 && dims[2] > 1 && dims[3] == 1  # 2D grid
    nodeid = (coord[2] * dims[2]) - (dims[2] - coord[1])  # (y * xlength) - (xlength - x)
  else # 3D grid
    #TODO
  end
end

"""
Return the coordinates of a node number on the grid
"""
function vertex_to_coord(vertex::Integer, model::AbstractModel)
  dims = model.grid.dimensions
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
Return other agents in the same node as the `agent`.
"""
function get_node_contents(agent::AbstractAgent, model::AbstractModel)
  agent_node = coord_to_vertex(agent.pos, model)
  ns = model.grid.agent_positions[agent_node]
end

"""
Return neighboring nodes of the node on which the agent resides.
"""
function node_neighbors(agent::AbstractAgent, model::AbstractModel)
  agent_node = coord_to_vertex(agent.pos, model)
  nn = neighbors(model.grid.grid, agent_node)
  nc = [vertex_to_coord(i, model) for i in nn]
end
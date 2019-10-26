export move_agent!, add_agent!, add_agent_single!,
move_agent_single!, kill_agent!

"""
    kill_agent!(agent::AbstractAgent, model::AbstractModel)

Remove an agent from the list of agents and from the space.
"""
function kill_agent!(agent::AbstractAgent, model::AbstractModel)
  if typeof(agent.pos) <: Tuple
    agentnode = coord2vertex(agent.pos, model)
  else
    agentnode = agent.pos
  end
   # remove from the space
  splice!(agent_positions(model)[agentnode],
          findfirst(a->a==agent.id, agent_positions(model)[agentnode]))
  splice!(model.agents, findfirst(a->a==agent, model.agents))  # remove from the model
end

"""
    move_agent!(agent::AbstractAgent, pos, model::AbstractModel)

Add `agentID` to the new position `pos` in the model and remove it from the old position
(also update the agent to have the new position).

If `pos` is a tuple, it represents the coordinates of the grid node.
If `pos` is an integer, it represents the node number in the graph.
If `pos` is not given, the agent is moved to a random position on the grid.
"""
function move_agent!(agent::AbstractAgent, pos::Tuple, model::AbstractModel)
  # node number from x, y, z coordinates
  nodenumber = coord2vertex(pos, model)
  move_agent!(agent, nodenumber, model)
end

function move_agent!(agent::AbstractAgent, pos::Integer, model::AbstractModel)
  push!(model.space.agent_positions[pos], agent.id)
  # remove agent from old position
  if typeof(agent.pos) <: Tuple
    oldnode = coord2vertex(agent.pos, model)
    splice!(model.space.agent_positions[oldnode], findfirst(a->a==agent.id, model.space.agent_positions[oldnode]))
    agent.pos = vertex2coord(pos, model)  # update agent position
  else
    splice!(model.space.agent_positions[agent.pos], findfirst(a->a==agent.id, model.space.agent_positions[agent.pos]))
    agent.pos = pos
  end
end

function move_agent!(agent::AbstractAgent, model::AbstractModel)
  nodenumber = rand(1:nv(model.space))
  move_agent!(agent, nodenumber, model)
  return agent.pos
end

"""
    move_agent_single!(agent::AbstractAgent, model::AbstractModel)

Move agent to a random nodes on the grid while respecting a maximum of one agent
per node. If there are no empty nodes, the agent wont move.

Return the agent's new position.
"""
function move_agent_single!(agent::AbstractAgent, model::AbstractModel)
  # TODO: this inefficient
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
"""
function add_agent!(agent::AbstractAgent, pos::Tuple, model::AbstractModel)
  # node number from x, y, z coordinates
  nodenumber = coord2vertex(pos, model)
  add_agent!(agent, nodenumber, model)
end

"""
    add_agent!(agent::AbstractAgent, pos::Integer, model::AbstractModel)

Adds the agent to the `pos` in the space and to the list of agents. `pos` is the node number of the space. If `pos` is not given, the agent is added to a random position.
"""
function add_agent!(agent::AbstractAgent, pos::Integer, model::AbstractModel)
  push!(model.space.agent_positions[pos], agent.id)
  push!(model.agents, agent)
  if typeof(agent.pos) <: Integer
    agent.pos = pos
  elseif typeof(agent.pos) <: Tuple
    agent.pos = vertex2coord(pos, model)  # update agent position
  else
    throw("Unknown type of agent.pos.")
  end
end


"""
    add_agent!(agent::AbstractAgent, model::AbstractModel)
Adds agent to a random node in the space and to the list of agents.

Returns the agent's new position.
"""
function add_agent!(agent::AbstractAgent, model::AbstractModel)
  nodenumber = rand(1:nv(model.space))
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

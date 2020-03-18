#=
This file establishes the agent-space interaction API.
=#
export move_agent!, add_agent!, add_agent_single!, add_agent_pos!,
move_agent_single!, kill_agent!, coord2vertex, vertex2coord, genocide!

#######################################################################################
# Killing agents
#######################################################################################
"""
    kill_agent!(agent::AbstractAgent, model::ABM)

Remove an agent from model, and from the space if the model has a space.
"""
function kill_agent!(agent::AbstractAgent, model::ABM{A, S}) where {A, S<:AbstractSpace}
  if typeof(agent.pos) <: Tuple
    agentnode = coord2vertex(agent.pos, model)
  else
    agentnode = agent.pos
  end
   # remove from the space
  splice!(agent_positions(model)[agentnode],
          findfirst(a->a==agent.id, agent_positions(model)[agentnode]))
  delete!(model.agents, agent.id)
  return model
end

function kill_agent!(agent::A, model::ABM{A, Nothing}) where A
  delete!(model.agents, agent.id)
end


"""
    genocide!(model::ABM)
Kill all the agents of the model.
"""
genocide!(model::ABM) = for (i, a) in model.agents; kill_agent!(a, model); end

"""
    genocide!(model::ABM, n::Int)
Kill the agents of the model whose IDs are larger than n.
"""
function genocide!(model::ABM, n::Int)
    for (k, v) in model.agents
        k > n && kill_agent!(v, model)
    end
end

"""
    genocide!(model::ABM, f::Function)
Kill all agents where the function `f(agent)` returns `true`.
"""
function genocide!(model::ABM, f::Function)
    for (k, v) in model.agents
        f(v) && kill_agent!(v, model)
    end
end

#######################################################################################
# Moving agents
#######################################################################################
"""
    move_agent!(agent::A [, pos], model::ABM{A, <: DiscreteSpace}) → agent

Add `agentID` to the new position `pos` in the model
and remove it from the old position
(also update the agent to have the new position).
`pos` must be the appropriate position type depending on the [`Space`](@ref) type,
e.g. `Int` for `GraphSpace`, `NTuple{<:AbstractFloat}}` for `ContinuousSpace`, etc.
"""
function move_agent!(agent::AbstractAgent, pos::Tuple, model::ABM)
  nodenumber = coord2vertex(pos, model)
  move_agent!(agent, nodenumber, model)
end

function move_agent!(agent::AbstractAgent, pos::Integer, model::ABM)
  # remove agent from old position
  if typeof(agent.pos) <: Tuple
    oldnode = coord2vertex(agent.pos, model)
    splice!(model.space.agent_positions[oldnode], findfirst(a->a==agent.id, model.space.agent_positions[oldnode]))
    agent.pos = vertex2coord(pos, model)  # update agent position
  else
    splice!(model.space.agent_positions[agent.pos], findfirst(a->a==agent.id, model.space.agent_positions[agent.pos]))
    agent.pos = pos
  end
  push!(model.space.agent_positions[pos], agent.id)
  return agent
end

function move_agent!(agent::AbstractAgent, model::ABM)
  nodenumber = rand(1:nv(model.space))
  move_agent!(agent, nodenumber, model)
  return agent
end

"""
    move_agent_single!(agent::AbstractAgent, model::ABM) → agent

Move agent to a random node while respecting a maximum of one agent
per node. If there are no empty nodes, the agent wont move.
Only valid for non-continuous spaces.
"""
function move_agent_single!(agent::AbstractAgent, model::ABM)
  # TODO: this inefficient
  empty_cells = [i for i in 1:length(model.space.agent_positions) if length(model.space.agent_positions[i]) == 0]
  if length(empty_cells) > 0
    random_node = rand(empty_cells)
    move_agent!(agent, random_node, model)
  end
  return agent
end

#######################################################################################
# Adding agents
#######################################################################################
"""
    add_agent!(agent::AbstractAgent [, pos], model::ABM) → agent

Add the agent to the `pos` in the space and to the list of agents.
If `pos` is not given, the agent is added to a random position.
The agent's position is always updated to match `pos`.
"""
function add_agent!(agent::AbstractAgent, pos::Tuple, model::ABM)
  # node number from x, y, z coordinates
  nodenumber = coord2vertex(pos, model)
  add_agent!(agent, nodenumber, model)
end

function add_agent!(agent::AbstractAgent, pos::Integer, model::ABM)
  push!(model.space.agent_positions[pos], agent.id)
  model.agents[agent.id] = agent
  # update agent position
  if typeof(agent.pos) <: Integer
    agent.pos = pos
  elseif typeof(agent.pos) <: Tuple
    agent.pos = vertex2coord(pos, model)
  else
    throw("Unknown type of agent.pos.")
  end
  return agent
end

function add_agent!(agent::AbstractAgent, model::ABM)
  if :pos ∈ fieldnames(typeof(agent))
    nodenumber = rand(1:nv(model.space))
    add_agent!(agent, nodenumber, model)
  else
    model.agents[agent.id] = agent
  end
  return agent
end

# TODO: the source code here can be massively simplified, by defining _first_
# add_agent_pos!, and have all other functions modify the agent's position and
# lastly call `add_agent_pos!`. This is done for continuous space and leads to super
# clean source code.
"""
    add_agent_pos!(agent::AbstractAgent, model::ABM) → agent
Add the agent to the `model` at the agent's own position.
"""
function add_agent_pos!(agent::AbstractAgent, model::ABM)
  if :pos ∈ fieldnames(typeof(agent))
    return add_agent!(agent, agent.pos, model)
  else
    return add_agent!(agent, model)
  end
end

"""
    add_agent_single!(agent::A, model::ABM{A, <: DiscreteSpace}) → agent

Add agent to a random node in the space while respecting a maximum one agent per node.
This function does not do anything if there are no empty nodes.
"""
function add_agent_single!(agent::A, model::ABM{A, <: DiscreteSpace}) where {A}
  msa = model.space.agent_positions
  empty_cells = [i for i in 1:length(msa) if length(msa[i]) == 0]
  if length(empty_cells) > 0
    random_node = rand(empty_cells)
    add_agent!(agent, random_node, model)
  end
  return agent
end

function biggest_id(model)
    if isempty(model.agents)
        return 0
    else
        return maximum(keys(model.agents))
    end
end

"""
    add_agent!(node, model::ABM, properties...)
Add a new agent in the given `node`, by constructing the agent type of
the `model` and propagating all *extra* `properties` to the constructor.

Notice that this function takes care of setting the agent's id and position and thus
`properties...` is propagated to other fields the agent has.

## Example
```julia
using Agents
mutable struct Agent <: AbstractAgent
    id::Int
    w::Float64
end
m = ABM(Agent) # model without spatial structure
add_agent!(m, 1, rand()) # incorrect: id is set internally
add_agent!(m, rand()) # correct: weight becomes rand()
```
"""
function add_agent!(node, model::ABM, properties...)
    id = biggest_id(model) + 1
    A = agenttype(model)
    cnode = correct_pos_type(node, model)
    agent = A(id, cnode, properties...)
    add_agent!(agent, cnode, model)
end

"""
    add_agent!(model::ABM, properties...)
Similar with `add_agent!(node, model, properties...)`, but adds the
created agent to a random node.
This function also works for models without a spatial structure.
"""
function add_agent!(model::ABM{A, Nothing}, properties...) where {A}
  @assert model.space == nothing
  id = biggest_id(model) + 1
  model.agents[id] = A(id, properties...)
  return model.agents[id]
end

function add_agent!(model::ABM{A, S}, properties...) where {A, S<:AbstractSpace}
  id = biggest_id(model) + 1
  n = rand(1:nv(model))
  cnode = correct_pos_type(n, model)
  model.agents[id] = A(id, cnode, properties...)
  push!(model.space.agent_positions[n], id)
  return model.agents[id]
end


"""
    add_agent_single!(model::ABM, properties...)
Same as `add_agent!(model, properties...)` but ensures that it adds an agent
into a node with no other agents (does nothing if no such node exists).
"""
function add_agent_single!(model::ABM, properties...)
  msa = model.space.agent_positions
  id = biggest_id(model) + 1
  A = agenttype(model)
  empty_cells = [i for i in 1:length(msa) if length(msa[i]) == 0]
  if length(empty_cells) > 0
    random_node = rand(empty_cells)
    cnode = correct_pos_type(node, model)
    agent = A(id, cnode, properties...)
    add_agent!(agent, random_node, model)
    return agent
  end
end

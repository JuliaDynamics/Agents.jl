#=
This file establishes the agent-space interaction API.
=#
export move_agent!, add_agent!, add_agent_single!, add_agent_pos!,
move_agent_single!, kill_agent!, genocide!

#######################################################################################
# Killing agents
#######################################################################################
"""
    kill_agent!(agent::AbstractAgent, model::ABM)

Remove an agent from model, and from the space if the model has a space.
"""
function kill_agent!(agent::AbstractAgent, model::ABM{A, S}) where {A, S<:AbstractSpace}
  agentnode = coord2vertex(agent.pos, model)
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

Add `agentID` to the new position `pos` (or a random one if `pos` is not given)
in the model and remove it from the old position
(also update the agent to have the new position).
`pos` must be the appropriate position type depending on the space type.
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
# TODO: the Source code of `add_agent!` for discrete space is overly complex.
# Similarly with the continuous
# space case, `add_agent_pos!` should be defined first and be the low-level method
# all other methods call. The other `add_agent!` methods simply prepare an agent with
# appropriate position and give it to `add_agent_pos!`

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
    add_agent!(agent::AbstractAgent [, position], model::ABM) → agent

Add the `agent` to the `position` in the space and to the list of agents.
If `position` is not given, the `agent` is added to a random position.
The `agent`'s position is always updated to match `position`, and therefore for `add_agent!`
the position of the `agent` is meaningless. Use [`add_agent_pos!`](@ref) to use
the `agent`'s position.
"""
function add_agent!(agent::A, pos::Tuple, model::ABM{A, <: DiscreteSpace}) where {A}
  # node number from x, y, z coordinates
  nodenumber = coord2vertex(pos, model)
  add_agent!(agent, nodenumber, model)
end

function add_agent!(agent::A, pos::Integer, model::ABM{A, <: DiscreteSpace}) where {A}
  push!(model.space.agent_positions[pos], agent.id)
  model[agent.id] = agent
  # update agent position
  agent.pos = correct_pos_type(pos, model)
  return agent
end

function add_agent!(agent::A, model::ABM{A, <: DiscreteSpace}) where {A}
  if :pos ∈ fieldnames(typeof(agent))
    nodenumber = rand(1:nv(model.space))
    add_agent!(agent, nodenumber, model)
  else
    model[agent.id] = agent
  end
  return agent
end


"""
    add_agent!([pos,] model::ABM, args...; kwargs...)
Create and add a new agent to the model by constructing an agent of the
type of the `model`. Propagate all *extra* positional arguments and
keyword arguemts to the agent constructor.

Notice that this function takes care of setting the agent's id *and* position and thus
`args...` and `kwargs...` are propagated to other fields the agent has.

Optionally provide a position to add the agent to as first argument.

## Example
```julia
using Agents
mutable struct Agent <: AbstractAgent
    id::Int
    pos::Int
    w::Float64
    k::Bool
end
Agent(id; w, k) = Agent(id, w, k) # keyword constructor
model = ABM(Agent, GraphSpace(complete_digraph(5)))

add_agent!(model, 1, 0.5, true) # incorrect: id is set internally
add_agent!(model, 0.5, true) # correct: weight becomes 0.5
add_agent!(5, model, 0.5, true) # add at node 5
add_agent!(model; w = 0.5, k =true) # use keywords: weight becomes 0.5
```
"""
function add_agent!(node, model::ABM{A, <: DiscreteSpace}, properties...; kwargs...) where {A}
    id = biggest_id(model) + 1
    cnode = correct_pos_type(node, model)
    agent = A(id, cnode, properties...; kwargs...)
    add_agent!(agent, cnode, model)
end

function add_agent!(model::ABM{A, Nothing}, properties...; kwargs...) where {A}
  @assert model.space == nothing
  id = biggest_id(model) + 1
  model[id] = A(id, properties...; kwargs...)
  return model[id]
end

function add_agent!(model::ABM{A, S}, properties...; kwargs...) where {A, S<:AbstractSpace}
  id = biggest_id(model) + 1
  n = rand(1:nv(model))
  cnode = correct_pos_type(n, model)
  model[id] = A(id, cnode, properties...; kwargs...)
  push!(model.space.agent_positions[n], id)
  return model[id]
end

biggest_id(model::ABM) = isempty(model.agents) ? 0 : maximum(keys(model.agents))


"""
    add_agent_single!(agent::A, model::ABM{A, <: DiscreteSpace}) → agent

Add agent to a random node in the space while respecting a maximum one agent per node.
This function throws a warning if no empty nodes remain.
"""
function add_agent_single!(agent::A, model::ABM{A, <: DiscreteSpace}) where {A}
  msa = model.space.agent_positions
  empty_cells = [i for i in 1:length(msa) if length(msa[i]) == 0]
  if length(empty_cells) > 0
    random_node = rand(empty_cells)
    add_agent!(agent, random_node, model)
  else
    @warn "No empty nodes found for `add_agent_single!`."
  end
  return agent
end

"""
    add_agent_single!(model::ABM{A, <: DiscreteSpace}, properties...; kwargs...)
Same as `add_agent!(model, properties...)` but ensures that it adds an agent
into a node with no other agents (does nothing if no such node exists).
"""
function add_agent_single!(model::ABM{A, <: DiscreteSpace}, properties...; kwargs...) where {A}
  id = biggest_id(model) + 1
  agent = A(id, 1, properties...; kwargs...)
  add_agent_single!(agent, model)
end

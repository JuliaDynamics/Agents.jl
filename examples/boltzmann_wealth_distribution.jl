using StatsBase
using Agents

# 1. define agent type
mutable struct MyAgent <: AbstractAgent
  id::Integer
  pos::Tuple{Integer, Integer}  # x,y,z coords
  wealth::Integer
end

# 2. define a model type
mutable struct MyModel <: AbstractModel
  space::AbstractSpace
  agents::Array{AbstractAgent}  # an array of agents
  scheduler::Function
end


# 3. define a space type
mutable struct MyGrid <: AbstractSpace
  dimensions::Tuple{Integer, Integer}
  space
  agent_positions::Array  # an array of arrays for each grid node
end

# 4. instantiate the model
function instantiate_model(;numagents, griddims)
  agents = [MyAgent(i, (1,1), 1) for i in 1:numagents]  # create a list of agents
  agent_positions = [Array{Integer}(undef, 0) for i in 1:gridsize(griddims)]  # an array of arrays for each node of the space
  mygrid = MyGrid(griddims, grid(griddims), agent_positions)  # instantiate the grid structure
  model = MyModel(mygrid, agents, random_activation)  # instantiate the model
  return model
end

model = instantiate_model(numagents=100, griddims=(5,5,1))

# 5 Agent step function: define what the agent does at each step
function agent_step!(agent::AbstractAgent, model::AbstractModel)
  if agent.wealth == 0
    return
  else
    agent2 = model.agents[rand(1:nagents(model))]
    agent.wealth -= 1
    agent2.wealth += 1
  end
end

# 4. Run the model 10 steps (only agent activations)
step!(agent_step!, model, 10)


# you may add one more function to the step!() function. This new function applies after the agent_step!(). Such functions can apply to change the model, e.g. change the number of individuals or change to the environment. Therefore, such models should only accept the model as their argument.
# step!(agent_step::Function, model_step::Function, model::AbstractModel, repeat::Integer)


# 7. You can add agents to the grid
# add agents to random positions. This update the `agent_positions` field of `model.space`. It is possible to add agents to specific nodes by specifying a node number of x,y,z coordinates
for agent in model.agents
  add_agent!(agent, model)
end

# Now we need to add to the agents’ behaviors, letting them move around and only give money to other agents in the same cell.
function agent_step!(agent::AbstractAgent, model::AbstractModel)
  if agent.wealth == 0
    return
  else
    available_agents = get_node_contents(agent, model)
    agent2id = rand(available_agents)
    agent.wealth -= 1
    agent2 = [i for i in model.agents if i.id == agent2id][1]
    agent2.wealth += 1
    # now move
    neighboring_nodes = node_neighbors(agent, model)
    move_agent!(agent, rand(neighboring_nodes), model)
  end
end

step!(agent_step!, model, 10)

# 8. collect data

properties = [:wealth]
aggregators = [StatsBase.mean, StatsBase.median, StatsBase.std]
steps_to_collect_data = collect(1:10)
#data = step!(agent_step!, model, 10, properties, aggregators, steps_to_collect_data)
data = step!(agent_step!, model, 10, properties, steps_to_collect_data)

# 9. explore data visually
visualize_data(data)

# 10. Running batch
data = batchrunner(agent_step!, model, 10, properties, aggregators, steps_to_collect_data, 10)

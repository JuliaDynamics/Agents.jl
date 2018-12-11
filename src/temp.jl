#= Lets write a simple model

The tutorial model is a very simple simulated agent-based economy, drawn from econophysics and presenting a statistical mechanics approach to wealth distribution [Dragulescu2002]_. The rules of our tutorial model:

* There are some number of agents.
* All agents begin with 1 unit of money.
* At every step of the model, an agent gives 1 unit of money (if they have it) to some other agent.

Despite its simplicity, this model yields results that are often unexpected to those not familiar with it. For our purposes, it also easily demonstrates Mesa’s core features.
=#


# 1 define agent type

mutable struct MyAgent <: AbstractAgent
  id::Integer
  pos::Tuple{Integer, Integer, Integer}  # x,y,z coords
  wealth::Integer
end

# 2 define a model

mutable struct MyModel <: AbstractModel
  grid::AbstractGrid
  agents::Array{AbstractAgent}  # a list of agents
  scheduler::Function
end

# 2.1 define a grid

mutable struct MyGrid <: AbstractGrid
  dimensions::Tuple{Integer, Integer, Integer}
  grid
  agent_positions::Array  # an array of arrays for each grid node
end

# 2.2 instantiate the model
agents = [MyAgent(i, (1,1,1), 1) for i in 1:100]
griddims = (5, 5, 1)
agent_positions = [Array{Integer}(undef, 0) for i in 1:gridsize(griddims)]
mygrid = MyGrid(griddims, grid(griddims), agent_positions)
model = MyModel(mygrid, agents, random_activation)

# 3 define what the agent does at each step

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

# 5. Plot some model results

# agents_plots_complete([(:wealth, :hist)], model)  # TODO: VegaLite does not show the plot

# 6. you may add one more function to the step!() function. This new function applies after the agent_step!(). Such functions can apply to change the model, e.g. change the number of individuals or change to the environment. Therefore, such models should only accept the model as their argument.
# step!(agent_step::Function, model_step::Function, model::AbstractModel, repeat::Integer)


# 7. You may add agents to the grid
# add agents to random positions. This update the `agent_positions` field of `model.grid`. It is possible to add agents to specific nodes by specifying a node number of x,y,z coordinates
for agent in model.agents
  add_agent_to_grid!(agent, model)
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
    move_agent_on_grid!(agent, rand(neighboring_nodes), model)
  end
end

step!(agent_step!, model, 10)

# 8. collect data

model_step!(model::AbstractModel) = return;  # a dummy model step
properties = [:wealth]
aggregators = [StatsBase.mean, StatsBase.median, StatsBase.std]
steps_to_collect_data = collect(1:10)
data = step!(agent_step!, model_step!, model, 10, properties, aggregators, steps_to_collect_data)
data = step!(agent_step!, model_step!, model, 10, properties, steps_to_collect_data)

# 9. explore data visually
visualize_data(data)

# 10. Running batch
data = batchrunner(agent_step!, model_step!, model, 10, properties, aggregators, steps_to_collect_data, 10)

###########
### END ###
###########


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

#####################################
### Schelling's segregation model ###
#####################################

#=

# Schelling Segregation Model

## Summary

The Schelling segregation model is a classic agent-based model, demonstrating how even a mild preference for similar neighbors can lead to a much higher degree of segregation than we would intuitively expect. The model consists of agents on a square grid, where each grid cell can contain at most one agent. Agents come in two colors: red and blue. They are happy if a certain number of their eight possible neighbors are of the same color, and unhappy otherwise. Unhappy agents will pick a random empty cell to move to each step, until they are happy. The model keeps running until there are no unhappy agents.
By default, the number of similar neighbors the agents need to be happy is set to 3. That means the agents would be perfectly happy with a majority of their neighbors being of a different color (e.g. a Blue agent would be happy with five Red neighbors and three Blue ones). Despite this, the model consistently leads to a high degree of segregation, with most agents ending up with no neighbors of a different color.
=#

# Create agent, model, and grid types
mutable struct SchellingAgent3 <: AbstractAgent
  id::Integer
  pos::Tuple{Integer, Integer, Integer}
  mood::Bool # true is happy and false is unhappy
  ethnicity::Integer  # type of agent
end

mutable struct SchellingModel <: AbstractModel
  grid::AbstractGrid
  agents::Array{AbstractAgent}  # a list of agents
  scheduler::Function
end

mutable struct MyGrid <: AbstractGrid
  dimensions::Tuple{Integer, Integer, Integer}
  grid
  agent_positions::Array  # an array of arrays for each grid node
end

# initialize the model
agents = vcat([SchellingAgent3(i, (1,1,1), false, 0) for i in 1:160], [SchellingAgent3(i, (1,1,1), false, 1) for i in 161:320])
griddims = (20, 20, 1)
agent_positions = [Array{Integer}(undef, 0) for i in 1:gridsize(griddims)]
mygrid = MyGrid(griddims, grid(griddims, true, true), agent_positions)
model = SchellingModel(mygrid, agents, random_activation)

# randomly distribute the agents on the grid
for agent in model.agents
  add_agent_to_grid_single!(agent, model)
end

# let them move
function agent_step!(agent, model)
  if agent.mood == true
    return
  end
  neighbor_cells = node_neighbors(agent, model)
  same = 0
  for nn in neighbor_cells
    nsid = get_node_contents(nn, model)
    if length(nsid) == 0
      continue
    else
      nsid = nsid[1]
    end
    ns = model.agents[nsid].ethnicity
    if ns == agent.ethnicity
      same += 1
    end
  end
  if same >= 5
    agent.mood = true
  else
    agent.mood = true
    # move
    move_agent_on_grid_single!(agent, model)
  end
end

step!(agent_step!, model)

###########
### END ###
###########


# Boltzmann wealth distribution

The Boltzmann wealth distribution is a simple agent-based model (ABM) in economics. Despite its simplicity, the model shows striking emergent wealth distribution. This model is the first in this set of examples that does not necessarily have a spatial structure. At first, we will build a model that does not have a spatial structure, and then we will modify the model to include a spatial structure. 

The Boltzmann model is conceptually very simple:

* We start with a number of agents, each of which have one unit of wealth.
* At every step, agents give one unit of their money (if they have any) to a random agent.
* We will see how wealth will be distributed after a few steps.

The code referenced in this tutorial is available in the [`examples/boltzmann_wealth_distribution.jl`](https://github.com/kavir1698/Agents.jl/blob/master/examples/boltzmann_wealth_distribution.jl) and [`examples/boltzmann_wealth_distribution_with_grid.jl`](https://github.com/kavir1698/Agents.jl/blob/master/examples/boltzmann_wealth_distribution_with_grid.jl) files on the Github repository.

## Building the model

Recall that Agents.jl structures simulations in three components: a _model_ component that keeps all model-level variables and data, an _agent_ component that keeps all agent-level variables and data, and a _space_ component that keeps space-level data. These components are provided in Agents.jl as abstract types, and this typing allows for tools from Agents.jl manage the rest of the path to producing data and visualizations.

Subtyping the model components in the following way will allow all the built-in functions to work on your defined types:

* The agent type should be a subtype of `AbstractAgent`.
* The model type should be a subtype of `AbstractModel`.
* The space type should be a subtype of `AbstractSpace`.

At first in this example, we will not be using a spatial structure:

```julia
using Agents

"""
Defines the agent type.

The agent type must be a subtype of AbstractAgent.

Commonly, an agent type will require a field for location value in the form
`pos::Tuple{T, T}`. In the first part of this example we will not be using a spatial
structure, therefore we will not define a field for position.

"""
mutable struct MyAgent{T<:Integer} <: AbstractAgent
  "The identifier number of the agent."
  id::T
  "The agent's wealth."
  wealth::T
end
```

The agent type has to have the `id` field and a `pos` field for position (if a spatial structure is used in the model). However, the agent can have any other fields that you desire, here we add a `wealth` field that accepts integers.

```julia
"Define the model type."
mutable struct MyModel{T<:AbstractVector} <: AbstractModel
  "An array of agents."
  agents::T
  "A field for the scheduler function."
  scheduler::Function
end
```

The model type has to have the `agents`, and `scheduler` fields. `agents` will be an array of all the agents, and `scheduler` will hold a function that specifies the order at which agents activate at each generation. See [Scheduler functions](@ref) for available scheduler functions.

Since we do not need a space structure for this first step, we will not define a space type and not create field for it in the model `struct`.

Now we write a function to instantiate the model:

```julia
"Function to instantiate the model."
function instantiate_model(; numagents)
  # Create a list of agents, each with position (1,1) and one unit of
  # wealth.
  agents = [MyAgent(i, 1) for i in 1:numagents]  

  # Instantiate and return the model.
  model = MyModel(agents, random_activation)
  return model
end
```

We can start our model by running the function and specifying `numagents`:

```julia
model = instantiate_model(numagents=100)
```

Now, we need to write a step function for agents. An step function should always take two positional arguments: first an agent object, and second a model object. Every agent will perform actions within this function at each step. Here, we say if an agent is activated (when defined by the scheduler) and has any wealth, then it should choose a random agent and give one unit of its wealth to said random agent.

```julia
"""
Define the agent step function.

Defines what the agent should do at each step.
"""
function agent_step!(agent::AbstractAgent, model::AbstractModel)
  # If the agent's wealth is zero, then do nothing.
  if agent.wealth == 0
    return
  # Otherwise, choose a random agent, subtract one unit of own wealth
  # and add one unit of wealth to the randomly chosen agent.
  else
    random_agent = model.agents[rand(1:nagents(model))]
    agent.wealth -= 1
    random_agent.wealth += 1
  end
end
```

Now we can run the model using the `step!` function (see [Model functions](@ref)). We can use the `step!` function from Agents.jl to run the model one step, without collecting data:

```julia
# Step the model once.
step!(agent_step!, model)
```

...or, similarly, to run the model multiple steps:

```julia
# Step the model 10 times.
step!(agent_step!, model, 10)
```

To run the model multiple steps and collect data we need to specify which properties to collect (`agent_properties` below) and on which steps to collect the data (`steps_to_collect_data` below):

```julia
# An array of Symbols for the agent fields that are to be collected, in
# this case wealth is the only variable to be collected.
agent_properties = [:wealth]
# Specifies at which steps data should be collected.
steps_to_collect_data = collect(1:10)
# Use the step function to run the model 10 times and collect data at
# each step.
data = step!(agent_step!, model, 10, agent_properties, steps_to_collect_data)
```

This code collects all agents' wealth at each step and stores them in a `DataFrame`. We can then interactively plot the data in DataVoyager and see the distribution of wealth at each step. This can be accomplished by simply using the `visualize_data` function:

```julia
visualize_data(data)
```

Often, in ABM we want to run a model many times and observe the average behavior of the system. We can do this easily with the `batchrunner` function. The first arguments to `batchrunner` are the same as the arguments passed to `step!`, and for `batchrunner` we also specify the number of replicates (15 in the below example):

```julia
model = instantiate_model(numagents=100)
# Run the model through 10 steps 15 separate times.
data = batchrunner(agent_step!, model, 10, agent_properties, steps_to_collect_data, 15)
```

In the model that we built so far, agents choose to give part of their wealth to any random agent. In the real world, transfers of wealth between people or groups are not likely to be completely random. Transfers are more likely to happen between people in the same network. 

For example, if a person hires a contractor to build a house, the contractor would be chosen from a network of some kind or another, and the contractor would not be chosen at random from all existing contractors. Perhaps the person would have a recommendation from a friend, or perhaps the contractor would be chosen from a pool of potential contractors in the same geographical area.

We can add a network effect similar to this by including a grid in our model and letting the agents interact only with those in the same node.

To that end, we will have to modify the model and agent types as well as write a space type:

```julia
"Define the model type."
mutable struct MyModel{T<:AbstractVector} <: AbstractModel
  "An array of agents."
  agents::T
  "A field for the scheduler function."
  scheduler::Function
  "The space field."
  space::S
end

"The space type that serves as the grid for the model."
mutable struct MyGrid{T<:Integer, Y<:AbstractVector} <: AbstractSpace
  "The dimensions of the grid."
  dimensions::Tuple{T, T}
  "A field for the space type."
  space::SimpleGraph
  "An array of arrays for each grid node."
  agent_positions::Y  
end
```

A few notes on the space type and the updated model:

* The space type requires the `dimensions`, `space`, and `agent_positions` fields.
* The field `dimensions` should be there only if you are using a grid space.
* The `space` field keeps the actual graph of the space.
* The `agent_positions` is always an array of arrays, where each array is for for each node of the space.
* The value of `agent.id` for each agent that is in the node will be stored in each node-array. 

We also have to modify the model instantiation function:

```julia
"Function to instantiate the model."
function instantiate_model(; numagents, griddims)
  # An array of arrays for each node of the space.
  agent_positions = [Int64[] for i in 1:gridsize(griddims)]
  # Instantiate the grid structure.
  mygrid = MyGrid(griddims, grid(griddims), agent_positions)
  # Create a list of agents, each with position (1,1) and one unit of
  # wealth.
  agents = [MyAgent(i, (1,1), 1) for i in 1:numagents]

  # Instantiate and return the model.
  model = MyModel(mygrid, MyAgent[], random_activation)

  # Use the `add_agent!` function to add agents to the model.
  for agent in agents
    add_agent!(agent, model)
  end

  return model
end
```

Now we can use our redefined instantiation function to instantiate a new model:

```julia
model = instantiate_model(numagents=100, griddims=(5,5))
```

We should now add agents to random positions on the grid. The `move_agent!` function updates the `agent_positions` field of `model.space` and the `pos` field of each agent. It is possible to add agents to specific nodes by specifying a node number of x,y,z coordinates (see [Space functions](@ref) for more details), however in this case the agent is placed on a random position on the grid.

```julia
# For each agent, move the agent to a random location on the grid by using the 
# `move_agent!` function.
for agent in model.agents
  move_agent!(agent, model)
end
```

We need a new step function that allows agents to give money only to other agents in the same cell. Also, the `agent_step!` function must move the agent to a different location in every step - if the agent were not moved on every step, the agents would just trade wealth amongst themselves.

```julia
"""
Define the agent step function.

Defines what the agent should do at each step.

"""
function agent_step!(agent::AbstractAgent, model::AbstractModel)
  # If the agent's wealth is zero, then do nothing.
  if agent.wealth == 0
    return
  # Otherwise..
  else
    #...create a list of all agents on the same node and select a random agent.
    available_agents = get_node_contents(agent, model)
    random_neighbor_agent_id = rand(available_agents)
    random_neighbor_agent = [i for i in model.agents
                             if i.id == random_neighbor_agent_id][1]
    # Then decrement the current agent's wealth and increment the neighbor's wealth.
    agent.wealth -= 1
    random_neighbor_agent.wealth += 1

    # Now move the agent to a random node.
    # If the agent weren't moved, agents would merely trade wealth 
    # amongst themselves on the same node.
    neighboring_nodes = node_neighbors(agent, model)
    move_agent!(agent, rand(neighboring_nodes), model)

  end
end
```

The model can be run as we did previously:

```julia
# Run the model multiple steps and collect data.
# An array of Symbols for the agent fields that are to be collected, in
# this case wealth is the only variable to be collected.
agent_properties = [:wealth]
# Specifies at which steps data should be collected.
steps_to_collect_data = collect(1:10)
# Use the step function to run the model 10 times and collect data at
# each step.
data = step!(agent_step!, model, 10, agent_properties, steps_to_collect_data)
```

...and the `visualize_data` function can be used to visualized the outcome of the experiment.

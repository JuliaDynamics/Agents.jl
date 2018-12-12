# Boltzmann wealth distribution

This is a simple agent-based model in economics. Despite its simplicity, it shows striking emergent wealth distribution. The first model that we will does not have spatial structure.

* We start with a number of agents all of which have one unit of wealth.
* At every step, agents give one unit of their money (if they have any) to a random agent.
* We will see how wealth will be distributed after a few steps.

The code of this tutorial is in the `examples/boltzmann_wealth_distribution.jl` file on the Github repository.

## Building the model

Agents.jl structures simulations in three components. A _model_ component that keeps all model-level variables and data, an _agent_ component that keeps all agent-level variables and data, and _space_ component that keeps space-level data.

At the beginning of each building any model, define your types for each of these components. After that, you will have to initialize your model, and write one or two functions to change angets and/or the model at each step. This will be all before you can run your model and analyze its results.

Now let's build our three types of this model:

These types should be subtypes of the following abstract types:

* The agent type should be a subtype of `AbstractAgent`.
* The model type should be a subtype of `AbstractModel`.
* The space type should be a subtype of `AbstractSpace`.

This subtyping will allow all the built-in functions to work on your define types.

```julia
# 1. define agent type
mutable struct MyAgent <: AbstractAgent
  id::Integer
  pos::Tuple{Integer, Integer, Integer}  # x,y,z coords
  wealth::Integer
end
```
The agent type has to have the `id` and the `pos` (for position) fields, but it can have any other fields that you desire. Here we add a `wealth` field that accepts integers. If your space is a grid, the position should accept a `Tuple{Integer, Integer, Integer}` representing x, y, z coordinates. Your grid does not have to be 3D. Here we want a regular 2D grid, so we will always keep `z=1`.

```julia
# 2. define a model type
mutable struct MyModel <: AbstractModel
  space::AbstractSpace
  agents::Array{AbstractAgent}  # an array of agents
  scheduler::Function
end
```

The model type has to have the `space`, `agents`, and `scheduler` fields. `space` will keep our space type, `agents` will be an array of all the agents, and `scheduler` will hold a function that specifies the order at which agents activate at each generation. See [Scheduler functions](@ref) for available scheduler functions, and [Space functions](@ref) for available space structures.

Since for this first step, we do not need a space structure, we will not define a space type and not create field for it in the model `struct`.

Now we write a function to instantiate the model:

```julia
# 4. instantiate the model
function instantiate_model(;numagents)
  agents = [MyAgent(i, (1,1,1), 1) for i in 1:numagents]  # create a list of agents
  model = MyModel(agents, random_activation)  # instantiate the model
  return model
end
```

We can start our model by running the function:

```julia
model = instantiate_model(numagents=100)
```

Now we have to write a step function for agents. An step function should always take two positional arguments: first an agent object, and second your model object. Every agent will perform actions within this function at each step. Here, we say if an agent activate (defined by the scheduler), and has any wealth, it should choose a random agent and give one unit of its wealth to it.

```julia
# Agent step function: define what the agent does at each step
function agent_step!(agent::AbstractAgent, model::AbstractModel)
  if agent.wealth == 0
    return
  else
    agent2 = model.agents[rand(1:nagents(model))]
    agent.wealth -= 1
    agent2.wealth += 1
  end
end
```

That's it. We can run the model. The `step!` function (see [Model functions](@ref)) runs the model. We can run it without collecting data for one step:

```julia
step!(agent_step!, model)
```

or for multiple steps:

```julia
step!(agent_step!, model, 10)
```

or we can run it for multiple steps and collect data:

```julia
agent_properties = [:wealth]
steps_to_collect_data = collect(1:10)
data = step!(agent_step!, model, 10, agent_properties, steps_to_collect_data)
```

This code collects all agents' wealth at each step and stores them in a `DataFrame`. 
We can then interactively plot the data in DataVoyager and see the distribution of wealth at each step

```julia
visualize_data(data)
```

Often, in ABM we want to run a model many times and observe the average behavior of the system. We can do this easily with the `batchrunner` function. It accepts the same arguments and in the same order as the `step!` function:

```julia
data = batchrunner(agent_step!, model_step!, model, 10, properties, aggregators, steps_to_collect_data, 10)
```

We can include a grid in our model and let the agents interact only with those in the same node. To that end, we will have to modify the model type and write a space type:

```julia
# Add grid field to the model type
mutable struct MyModel <: AbstractModel
  grid::AbstractSpace
  agents::Array{AbstractAgent}  # an array of agents
  scheduler::Function
end

# define a space type
mutable struct MyGrid <: AbstractSpace
  dimensions::Tuple{Integer, Integer, Integer}
  space
  agent_positions::Array  # an array of arrays for each grid node
end
```

The space type has to have the `dimensions`, `space`, and `agent_positions` fields. `dimensions` should be there only if you are using a grid space. The `space` field keeps the actual graph of the space. The `agent_positions` is always an array of arrays. An array for each node of the space. It will be used to keep the `agent.id`s of agents in each node.

We also have to modify the model instantiation function:

```julia
function instantiate_model(;numagents, griddims)
  agents = [MyAgent(i, (1,1,1), 1) for i in 1:numagents]  # create a list of agents
  agent_positions = [Array{Integer}(undef, 0) for i in 1:gridsize(griddims)]  # an array of arrays for each node of the space
  mygrid = MyGrid(griddims, grid(griddims), agent_positions)  # instantiate the grid structure
  model = MyModel(mygrid, agents, random_activation)  # instantiate the model
  return model
end

model = instantiate_model(numagents=100, griddims=(5,5,1))
```

We should now add agents to random positions on the grid. The `add_agent_to_grid!`  function updates the `agent_positions` field of `model.space`. It is possible to add agents to specific nodes by specifying a node number of x,y,z coordinates (see [Space functions](@ref) for more details).

```julia
for agent in model.agents
  add_agent_to_grid!(agent, model)
end
```

The model can be run as we did previously.
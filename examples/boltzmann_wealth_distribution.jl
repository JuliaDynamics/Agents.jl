"""
The first part of the Boltzmann Wealth Distribution example. 

In the first part of the Boltzmann example, the experiment is ran without
a spatial structure. In the second part, a spatial structure is added,
and agents are required to only give money to agents who are on the 
same node.

This example can be ran by navigating to the examples/ folder, starting 
a julia REPL session and running:

```
julia> include("boltzmann_wealth_distribution.jl")
```

This will instantiate the model and create a `DataFrame` `data` that 
contains the result of running the model 10 steps. After running the
model, the results can be visualized in DataVoyager like this: 

```
julia> visualize_data(data);
```

...which should result in a pop-up window that displays graphs 
depicting the results of the experiment.

"""
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

"Define the model type."
mutable struct MyModel{T<:AbstractVector} <: ABM
  "An array of agents."
  agents::T
  "A field for the scheduler function."
  scheduler::Function
end

"Function to instantiate the model."
function instantiate_model(; numagents)
  # Create a list of agents, each with position (1,1) and one unit of
  # wealth.
  agents = [MyAgent(i, 1) for i in 1:numagents]  

  # Instantiate and return the model.
  model = MyModel(agents, random_activation)
  return model
end


"""
Define the agent step function.

Defines what the agent should do at each step.
"""
function agent_step!(agent::AbstractAgent, model::ABM)
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

# Instantiate the model.
model = instantiate_model(numagents=100)

# Run the model multiple steps and collect data.
# An array of Symbols for the agent fields that are to be collected, in
# this case wealth is the only variable to be collected.
agent_properties = [:wealth]
# Specifies at which steps data should be collected.
when = collect(1:10)
# Use the step function to run the model 10 times and collect data at
# each step.
data = step!(agent_step!, model, 10, agent_properties, when)

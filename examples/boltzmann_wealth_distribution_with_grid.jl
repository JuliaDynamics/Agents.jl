"""
The second part of the Boltzmann Wealth Distribution example. 

In the first part of the Boltzmann example, the experiment is ran without
a spatial structure. In the second part, a spatial structure is added,
and agents are required to only give money to agents who are on the 
same node.

This example can be ran by navigating to the examples/ folder, starting 
a julia REPL session and running:

```
julia> include("boltzmann_wealth_distribution_with_grid.jl")
```

This will instantiate the model and create a `DataFrame` `data` that 
contains the result of running the model 10 steps. After running the
model, the results can be visualized in DataVoyager like this: 

```
using DataVoyager
julia> Voyager(data);
```

...which should result in a pop-up window that displays graphs 
depicting the results of the experiment.

"""

using Agents

"""
Defines the agent type.

The agent type must be a subtype of AbstractAgent.

"""
mutable struct Boltzmann{T<:Integer} <: AbstractAgent
  "The identifier number of the agent."
  id::T
  pos::Tuple{T, T}
  "The agent's wealth."
  wealth::T
end

"Function to instantiate the model."
function instantiate_model(; numagents, griddims)
  space = Space(griddims)
  model = ABM(Boltzmann{Int64}, space, scheduler=random_activation)

  # Add agents to random positions, each with one unit of wealth.
  for i in 1:numagents
    add_agent!(Boltzmann(i, (1,1), 1), model)
  end
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
  # Otherwise..
  else
    #...create a list of all agents on the same node and select a random agent.
    available_agents = get_node_contents(agent, model)
    random_neighbor_agent = model.agents[rand(available_agents)]
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

# Instantiate the model.
model = instantiate_model(numagents=100, griddims=(5,5))

# Run the model multiple steps and collect data.
# An array of Symbols for the agent fields that are to be collected, in
# this case wealth is the only variable to be collected.
agent_properties = [:wealth]
# Specifies at which steps data should be collected.
when = 1:10
# Use the step function to run the model 10 times and collect data at
# each step.
data = step!(model, agent_step!, 10, agent_properties, when=when)

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
julia> visualize_data(data);
```

...which should result in a pop-up window that displays graphs 
depicting the results of the experiment.

"""

using Agents

"""
Defines the agent type.

The agent type must be a subtype of AbstractAgent.

"""
mutable struct MyAgent{T<:Integer} <: AbstractAgent
  "The identifier number of the agent."
  id::T
  "The agent's grid position."
  pos::Tuple{T, T}
  "The agent's wealth."
  wealth::T
end

"Define the model type."
mutable struct MyModel{A<:AbstractVector, S<:AbstractSpace} <: ABM
  "A space dimension."
  space::S
  "An array of agents."
  agents::A
  "A field for the scheduler function."
  scheduler::Function
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

"Function to instantiate the model."
function instantiate_model(; numagents, griddims)
  # An array of arrays for each node of the space.
  agent_positions = [Int64[] for i in 1:nv(griddims)]
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

# Instantiate the model.
model = instantiate_model(numagents=100, griddims=(5,5))

# For each agent, move the agent to a random location on the grid by using the 
# `move_agent!` function.
for agent in model.agents
  move_agent!(agent, model)
end

# Run the model multiple steps and collect data.
# An array of Symbols for the agent fields that are to be collected, in
# this case wealth is the only variable to be collected.
agent_properties = [:wealth]
# Specifies at which steps data should be collected.
when = collect(1:10)
# Use the step function to run the model 10 times and collect data at
# each step.
data = step!(agent_step!, model, 10, agent_properties, when)

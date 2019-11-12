#= This is an implementation of Schelling's segregation model

* There are agents on a grid
* Agents are of two different kinds. They can represent different groups.
* Only one agent can be at a node on the grid.
  * Each node represents a house, and only one a person/family can live in a house.
* Agents are happy even if a majority of their neighbors are of a different kind.
* If they are unhappy, they move to a random empty node until they are happy.

This model shows that even a slight preference for being around neighbors of the same kind leads to segregated
neighborhoods.

=#

using Agents

# Create the agent, model, and grid types.
"ABM type for the Schelling Model"
mutable struct SchellingModel{T<:Integer, Y<:AbstractArray, Z<:AbstractSpace} <: ABM 
  # Object should always be a subtype of ABM.
  "A field of the model for a space object, always a subtype of AbstractSpace."
  space::Z 
  "A list of agents."
  agents::Y
  "A field for the scheduler function."
  scheduler::Function
  "The minimum number of neighbors for agent to be happy."
  min_to_be_happy::T
end

"AbstractAgent type for the Schelling Agent"
mutable struct SchellingAgent{T<:Integer} <: AbstractAgent # Object should always be a subtype of AbstractAgent
  "The identifier number of the agent."
  id::T
  "The x, y location of the agent."
  pos::Tuple{T, T}
  "Whether or not the agent is happy with cell (true is 'happy' and false is 'unhappy')."
  mood::Bool
  "The group of the agent, determines mood as it interacts with neighbors."
  group::T
end

"The space of the experiment."
mutable struct MyGrid{T<:Integer, Y<:AbstractArray} <: AbstractSpace
  "Dimensions of the grid."
  dimensions::Tuple{T, T}
  "The space type."
  space::SimpleGraph
  "An array of arrays for each grid node."
  agent_positions::Y  
end

"Function to instantiate the model."
function instantiate_model(;numagents=320, griddims=(20, 20), min_to_be_happy=3)
  # Create an empty Array of Arrays.
  agent_positions = [Int64[] for i in 1:gridsize(griddims)]
  # Use MyGrid to create a grid from griddims and agent_positions using the grid function.
  # Create a 2D grid with nodes have a max of 8 neighbors.
  mygrid = MyGrid(griddims, grid(griddims, false, true), agent_positions)
  # Instantiate the model using mygrid, the SchellingAgent type, the random_activation function from Agents.jl
  # and the argument min_to_be_happy.
  model = SchellingModel(mygrid, SchellingAgent[], random_activation, min_to_be_happy) 
  
  # Create a 1-dimension list of agents, balanced evenly between group 0 and group 1.
  agents = vcat(
    [SchellingAgent(Int(i), (1,1), false, 0) for i in 1:(numagents/2)],
    [SchellingAgent(Int(i), (1,1), false, 1) for i in (numagents/2)+1:numagents]
  )

  # Add the agents to the model.
  for agent in agents
    # Use add_agent_single (from Agents.jl) to add the agents to the grid at random locations.
    add_agent_single!(agent, model)
  end
  return model
end

"Move a single agent until a satisfactory location is found."
function agent_step!(agent, model)
  if agent.mood == true
    return
  end
  while agent.mood == false
    neighbor_cells = node_neighbors(agent, model)
    count_neighbors_same_group = 0

	# For each neighbor, get group and compare to current agent's group...
    # ...and increment count_neighbors_same_group as appropriately.  
    for neighbor_cell in neighbor_cells
      node_contents = get_node_contents(neighbor_cell, model)
      # Skip iteration if the node is empty.
      if length(node_contents) == 0
        continue
      else
        # Otherwise, get the first agent in the node...
        node_contents = node_contents[1]
      end
      # ...and increment count_neighbors_same_group if the neighbor's group is the same.
      neighbor_agent_group = model.agents[node_contents].group
      if neighbor_agent_group == agent.group
        count_neighbors_same_group += 1
      end
    end

    # After evaluating and adding up the groups of the neighbors, decide whether or not to move the agent.
    # If count_neighbors_same_group is at least the min_to_be_happy, set the mood to true. Otherwise, 
	# move the agent using move_agent_single.
    if count_neighbors_same_group >= model.min_to_be_happy
      agent.mood = true
    else
      move_agent_single!(agent, model)
    end
  end
end

# Instantiate the model with 370 agents on a 20 by 20 grid. 
model = instantiate_model(numagents=370, griddims=(20,20), min_to_be_happy=3)
# An array of Symbols for the agent fields that are to be collected.
agent_properties = [:pos, :mood, :group]
# Specifies at which steps data should be collected.
when = collect(1:2)
# Use the step function to run the model and collect data.
data = step!(agent_step!, model, 2, agent_properties, when)

# Use visualize_2D_agent_distribution to plot distribution of agents at every step.
for i in 1:2
  visualize_2D_agent_distribution(data, model, Symbol("pos_$i"), types=Symbol("group_$i"), savename="step_$i",
								  cc=Dict(0=>"blue", 1=>"red"))
end

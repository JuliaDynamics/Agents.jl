#= This is an implementation of Schelling's segregation model

* There are agents on a grid
* Agents are of two different kinds. They can represent ethnicity, for example.
* Only one agent can be at a node on the grid. Each node represents a house, and only one a person/family can live in a house.
* Agents are happy even if a majority of their neighbors are of a different kind.
* If they are unhappy, they move to a random empty node until they are happy.

This model shows that even a slight preference for being around neighbors of the same kind leads to segregated neighborhoods.
=#

using Agents

# Create agent, model, and grid types
mutable struct SchellingAgent <: AbstractAgent # An agent
# object should always be a subtype of AbstractAgent
  id::Integer
  pos::Tuple{Integer, Integer}
  mood::Bool # true is happy and false is unhappy
  ethnicity::Integer
end

mutable struct SchellingModel <: AbstractModel  # A model
	# object should always be a subtype of AbstractModel
	space::AbstractSpace  # A space object, which is a field
	# of the model object is always subtype of AbstractSpace
	agents::Array{AbstractAgent}  # a list of agents
	scheduler::Function
	min_to_be_happy::Integer  # minimum number of neighbors 
	#to be of the same kind so that they are happy
end

mutable struct MyGrid <: AbstractSpace
  dimensions::Tuple{Integer, Integer}
  space
  agent_positions::Array  # an array of arrays for each grid node
end

# instantiate the model
function instantiate_model(;numagents=320, griddims=(20, 20), min_to_be_happy=3)
  agent_positions = [Array{Integer}(undef, 0) for i in 1:gridsize(griddims)]
  mygrid = MyGrid(griddims, grid(griddims, false, true), agent_positions)  # create a 2D grid with nodes have a max of 8 neighbors
  model = SchellingModel(mygrid, AbstractAgent[], random_activation, min_to_be_happy) 
  
  agents = vcat([SchellingAgent(i, (1,1), false, 0) for i in 1:(numagents/2)], [SchellingAgent(i, (1,1), false, 1) for i in (numagents/2)+1:numagents])
  for agent in agents
    add_agent_single!(agent, model)
  end
  return model
end

function agent_step!(agent, model)
  if agent.mood == true
    return
  end
  while agent.mood == false
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
    if same >= model.min_to_be_happy
      agent.mood = true
    else
      move_agent_single!(agent, model)
    end
  end
end

model = instantiate_model(numagents=200, griddims=(20,20), min_to_be_happy=2)
agent_properties = [:pos, :mood, :ethnicity]
steps_to_collect_data = collect(1:4)
data = step!(agent_step!, model, 4, agent_properties, steps_to_collect_data)
for i in 1:4
  visualize_2D_agent_distribution(data, model, Symbol("pos_$i"), types=Symbol("ethnicity_$i"), savename="step_$i", cc=Dict(0=>"blue", 1=>"red"))
end

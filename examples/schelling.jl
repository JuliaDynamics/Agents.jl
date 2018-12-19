#= This is an implementation of Schelling's segregation model

* There are agents on a square grid
* Agents are of two different kinds. They can represent ethnicity, for example.
* Only one agent can be at a node on the grid. Each node represents a house, and only one a person/family can live in a house.
* Agents are happy even if a majority (maximum 5/8) of their neighbors are of a different kind.
* If they are unhappy, they more to a random empty node.

This model shows that even a slight preference for being around neighbors of the same kind leads to segregated neighborhoods
=#

using Agents

# Create agent, model, and grid types
mutable struct SchellingAgent <: AbstractAgent
  id::Integer
  pos::Tuple{Integer, Integer}
  mood::Bool # true is happy and false is unhappy
  ethnicity::Integer  # type of agent
end

mutable struct SchellingModel <: AbstractModel
  space::AbstractSpace
  agents::Array{AbstractAgent}  # a list of agents
  scheduler::Function
end

mutable struct MyGrid <: AbstractSpace
  dimensions::Tuple{Integer, Integer}
  space
  agent_positions::Array  # an array of arrays for each grid node
  min_to_be_happy::Integer  # minimum number of neighbors to be of the same kind so that they are happy
end

# instantiate the model
function instantiate_model(;numagents=320, griddims=(20, 20), min_to_be_happy=3)
  agents = vcat([SchellingAgent(i, (1,1), false, 0) for i in 1:(numagents/2)], [SchellingAgent(i, (1,1), false, 1) for i in (numagents/2)+1:numagents])
  agent_positions = [Array{Integer}(undef, 0) for i in 1:gridsize(griddims)]
  mygrid = MyGrid(griddims, grid(griddims, true, true), agent_positions)  # create a 2D grid with nodes have a max of 8 neighbors
  model = SchellingModel(mygrid, agents, random_activation, min_to_be_happy) 

  # randomly distribute the agents on the grid
  for agent in model.agents
    add_agent_single!(agent, model)
  end
end

instantiate_model()


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
  if same >= modelmin_to_be_happy
    agent.mood = true
  else
    agent.mood = true
    # move
    move_agent_on_grid_single!(agent, model)
  end
end


step!(agent_step!, model, 3)


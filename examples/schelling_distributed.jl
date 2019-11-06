#= This is The same implementation of schelling.jl, except that we run replicate simulations in parallel.

To run simulations in parallel, you need to define all types and functions on all the workers, i.e. processing cores. Use the `@everywhere` for that.
=#

using Distributed
addprocs(3)  # Add the number of parallel processing units
@everywhere using Agents


# Create agent, model, and grid types
@everywhere mutable struct SchellingAgent{T<:Integer} <: AbstractAgent # An agent
# object should always be a subtype of AbstractAgent
  id::T
  pos::Tuple{T, T}
  mood::Bool # true is happy and false is unhappy
  group::T
end

@everywhere mutable struct SchellingModel{T<:Integer, Y<:AbstractArray, Z<:AbstractSpace} <: AbstractModel  # A model
	# object should always be a subtype of AbstractModel
	space::Z  # A space object, which is a field
	# of the model object is always subtype of AbstractSpace
	agents::Y  # a list of agents
	scheduler::Function
	min_to_be_happy::T  # minimum number of neighbors 
	#to be of the same kind so that they are happy
end

@everywhere mutable struct MyGrid{T<:Integer, Y<:AbstractArray} <: AbstractSpace
  dimensions::Tuple{T, T}
  space::SimpleGraph
  agent_positions::Y  # an array of arrays for each grid node
end

# instantiate the model
@everywhere function instantiate_model(;numagents=320, griddims=(20, 20), min_to_be_happy=3)
  agent_positions = [Int64[] for i in 1:gridsize(griddims)]
  mygrid = MyGrid(griddims, grid(griddims, false, true), agent_positions)  # create a 2D grid with nodes have a max of 8 neighbors
  model = SchellingModel(mygrid, SchellingAgent[], random_activation, min_to_be_happy) 
  
  agents = vcat([SchellingAgent(Int(i), (1,1), false, 0) for i in 1:(numagents/2)], [SchellingAgent(Int(i), (1,1), false, 1) for i in (numagents/2)+1:numagents])
  for agent in agents
    add_agent_single!(agent, model)
  end
  return model
end

@everywhere function agent_step!(agent, model)
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
      ns = model.agents[nsid].group
      if ns == agent.group
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


@everywhere agent_properties = [:pos, :mood, :group]
@everywhere when = collect(1:2)
model = instantiate_model(numagents=370, griddims=(20,20), min_to_be_happy=3);
nsteps = 3
nreplicates = 10
all_data = batchrunner_parallel(agent_step!, model, nsteps, agent_properties, when, nreplicates);
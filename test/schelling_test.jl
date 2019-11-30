
mutable struct SchellingAgent <: AbstractAgent
  id::Int # The identifier number of the agent
  pos::Tuple{Int,Int} # The x, y location of the agent
  mood::Bool # whether the agent is happy in its node. (true = happy)
  group::Int # The group of the agent,
             # determines mood as it interacts with neighbors
end


function instantiate_modelS(;numagents=320, griddims=(20, 20), min_to_be_happy=3)

  space = Space(griddims, moore = true)

  properties = Dict(:min_to_be_happy => min_to_be_happy)
  schelling = ABM(SchellingAgent, space; properties = properties, scheduler=random_activation)

  for n in 1:numagents
    agent = SchellingAgent(n, (1,1), false, n < numagents/2 ? 1 : 2)
    add_agent_single!(agent, schelling)
  end
  return schelling
end

function agent_step!(agent, model)
  agent.mood == true && return # do nothing if already happy
  minhappy = model.properties[:min_to_be_happy]
  # while agent.mood == false
      neighbor_cells = node_neighbors(agent, model)
      count_neighbors_same_group = 0
      # For each neighbor, get group and compare to current agent's group
      # and increment count_neighbors_same_group as appropriately.
      for neighbor_cell in neighbor_cells
          node_contents = get_node_contents(neighbor_cell, model)
          # Skip iteration if the node is empty.
          length(node_contents) == 0 && continue
          # Otherwise, get the first agent in the node...
          agent_id = node_contents[1]
          # ...and increment count_neighbors_same_group if the neighbor's group is
          # the same.
          neighbor_agent_group = model.agents[agent_id].group
          if neighbor_agent_group == agent.group
              count_neighbors_same_group += 1
          end
      end

      # After counting the neighbors, decide whether or not to move the agent.
      # If count_neighbors_same_group is at least the min_to_be_happy, set the
      # mood to true. Otherwise, move the agent to a random node.
      if count_neighbors_same_group ≥ minhappy
          agent.mood = true
      else
          move_agent_single!(agent, model)
      end
  # end
  # return
end

@testset "Schelling example" begin
  Random.seed!(123)
  model = instantiate_modelS(numagents=370, griddims=(20,20), min_to_be_happy=3)
  agent_properties = [:pos, :mood, :group]
  when = 1:5
  data = step!(model, agent_step!, 2, agent_properties, when=when)

  @test data[1, :pos] == 363
  @test data[end, :pos] == 341
end

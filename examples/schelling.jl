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

mutable struct SchellingAgent <: AbstractAgent
  id::Int # The identifier number of the agent
  pos::Tuple{Int,Int} # The x, y location of the agent
  mood::Bool # whether the agent is happy in its node. (true = happy)
  group::Int # The group of the agent,
             # determines mood as it interacts with neighbors
end

"Function to instantiate the model."
function instantiate(;numagents=320, griddims=(20, 20), min_to_be_happy=3)
    space = Space(griddims, moore = true) # make a Moore grid
    properties = Dict(:min_to_be_happy => 3)
    model = ABM(SchellingAgent, space; properties=properties, scheduler = random_activation)
    # populate the model with agents, adding equal amount of the two types of agents
    # at random positions in the model
    for n in 1:numagents
        agent = SchellingAgent(n, (1,1), false, n < numagents/2 ? 1 : 2)
        add_agent_single!(agent, model)
    end
    return model
end

"Move a single agent until a satisfactory location is found."
function agent_step!(agent, model)
    agent.mood == true && return # do nothing if already happy
    minhappy = model.properties[:min_to_be_happy]
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
    return
end

# Instantiate the model with 370 agents on a 20 by 20 grid. 
model = instantiate_model(numagents=370, griddims=(20,20), min_to_be_happy=3)
# An array of Symbols for the agent fields that are to be collected.
agent_properties = [:pos, :mood, :group]
# Specifies at which steps data should be collected.
when = 1:2
# Use the step function to run the model and collect data.
data = step!(model, agent_step!, 2, agent_properties, when=when)

# Use visualize_2D_agent_distribution to plot distribution of agents at every step.
using AgentsPlots
for i in 1:2
  visualize_2D_agent_distribution(data, model, Symbol("pos_$i"), types=Symbol("group_$i"), savename="step_$i",
								  cc=Dict(0=>"blue", 1=>"red"))
end

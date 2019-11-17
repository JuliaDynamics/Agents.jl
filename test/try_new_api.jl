using Agents
mutable struct SchellingAgent <: AbstractAgent
  id::Int # The identifier number of the agent
  pos::Tuple{Int,Int} # The x, y location of the agent
  mood::Bool # whether the agent is happy in its node. (true = happy)
  group::Int # The group of the agent,
             # determines mood as it interacts with neighbors
end

space = Space((10,10), moore = true)

properties = Dict(:min_to_be_happy => 3)

schelling = ABM(SchellingAgent, space; properties = properties)

agent = SchellingAgent(6, (1,1), false, 1)
add_agent_single!(agent, schelling)


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

model = instantiate()

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

happyperc(model) = count(x -> x.mood == true, values(model.agents))/nagents(model)

step!(model, agent_step!)  # Run the model one step...
happyperc(model)

# %%
model = instantiate()
properties = [:pos, :mood]
when = 1:2
data = step!(model, agent_step!, 2, properties, when=when)

model = instantiate()
data = step!(model, agent_step!, 2, properties, when=when, replicates=5)

model = instantiate()
properties = Dict(:mood=>[sum])
when = 1:2
data = step!(model, agent_step!, 2, properties, when=when)
mutable struct SchellingAgent <: AbstractAgent
    id::Int # The identifier number of the agent
    pos::Tuple{Int,Int} # The x, y location of the agent on a 2D grid
    mood::Bool # whether the agent is happy in its position. (true = happy)
    group::Int # The group of the agent,  determines mood as it interacts with neighbors
end

"""
``` julia
schelling(; 
    numagents = 320, 
    griddims = (20, 20), 
    min_to_be_happy = 3
)
```
Same as in [Schelling's segregation model](@ref).
"""
function schelling(; numagents = 320, griddims = (20, 20), min_to_be_happy = 3)
    @assert numagents < prod(griddims)
    space = GridSpace(griddims, periodic = false)
    properties = Dict(:min_to_be_happy => min_to_be_happy)
    model =
        ABM(SchellingAgent, space; properties = properties, scheduler = random_activation)
    ## populate the model with agents, adding equal amount of the two types of agents
    ## at random positions in the model
    for n in 1:numagents
        agent = SchellingAgent(n, (1, 1), false, n < numagents / 2 ? 1 : 2)
        add_agent_single!(agent, model)
    end
    return model, schelling_agent_step!, dummystep
end


function schelling_agent_step!(agent, model)
    agent.mood == true && return # do nothing if already happy
    count_neighbors_same_group = 0
    ## For each neighbor, get group and compare to current agent's group
    ## and increment count_neighbors_same_group as appropriately.
    for neighbor in nearby_agents(agent, model)
        if agent.group == neighbor.group
            count_neighbors_same_group += 1
        end
    end
    ## After counting the neighbors, decide whether or not to move the agent.
    ## If count_neighbors_same_group is at least the min_to_be_happy, set the
    ## mood to true. Otherwise, move the agent to a random position.
    if count_neighbors_same_group ≥ model.min_to_be_happy
        agent.mood = true
    else
        move_agent_single!(agent, model)
    end
    return
end

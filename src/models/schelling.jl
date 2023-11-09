@agent struct SchellingAgent(GridAgent{2})
    mood::Bool # whether the agent is happy in its position. (true = happy)
    group::Int # The group of the agent,  determines mood as it interacts with neighbors
end

"""
```julia
schelling(;
    numagents = 320,
    griddims = (20, 20),
    min_to_be_happy = 3,
)
```
Same as in [Schelling's segregation model](@ref).
"""
function schelling(; numagents = 320, griddims = (20, 20), min_to_be_happy = 3)
    @assert numagents < prod(griddims)
    space = GridSpaceSingle(griddims, periodic = false)
    properties = Dict(:min_to_be_happy => min_to_be_happy)
    model = StandardABM(SchellingAgent, space; properties, agent_step! = schelling_agent_step!,
                        container = Vector, scheduler = Schedulers.Randomly())
    for n in 1:numagents
        add_agent_single!(SchellingAgent, model, false, n < numagents / 2 ? 1 : 2)
    end
    return model
end

function schelling_agent_step!(agent, model)
    agent.mood == true && return # do nothing if already happy
    count_neighbors_same_group = 0
    for neighbor in nearby_agents(agent, model)
        if agent.group == neighbor.group
            count_neighbors_same_group += 1
        end
    end
    if count_neighbors_same_group ≥ model.min_to_be_happy
        agent.mood = true
    else
        move_agent_single!(agent, model)
    end
end

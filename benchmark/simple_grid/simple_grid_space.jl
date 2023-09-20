@agent struct SoloGridSpaceAgent(GridAgent{2})
    group::Int
    happy::Bool
end

# Notice that these functions are fully identical with the GridSpace version.
function initialize_sologridspace()
    space = GridSpaceSingle(grid_size; periodic = false)
    properties = Dict(:min_to_be_happy => min_to_be_happy)
    rng = Random.Xoshiro(rand(UInt))
    model = ABM(SoloGridSpaceAgent, space; properties, rng)
    N = grid_size[1]*grid_size[2]*grid_occupation
    for n in 1:N
        group = n < N / 2 ? 1 : 2
        add_agent_single!(SoloGridSpaceAgent, model, group, false)
    end
    return model
end

function agent_step_sologridspace!(agent, model)
    nearby_same = count_nearby_same(agent, model)
    if nearby_same ≥ model.min_to_be_happy
        agent.happy = true
    else
        move_agent_single!(agent, model)
    end
    return
end
function count_nearby_same(agent, model)
    nearby_same = 0
    for neighbor in nearby_agents(agent, model)
        if agent.group == neighbor.group
            nearby_same += 1
        end
    end
    return nearby_same
end

model_sologridspace = initialize_sologridspace()
println("Benchmarking GridSpaceSingle version")
@btime step!($model_sologridspace, agent_step_sologridspace!) setup = (model_sologridspace = initialize_sologridspace())

println("Benchmarking GridSpaceSingle version: count nearby same")
model = initialize_sologridspace()
@btime count_nearby_same(agent, model) setup = (agent = random_agent(model))

mutable struct GridSpaceAgent <: AbstractAgent
    id::Int
    pos::NTuple{2, Int} # Notice that position type depends on space-to-be-used
    group::Int
    happy::Bool
end

function initialize_gridspace()
    space = GridSpace(grid_size; periodic = false)
    properties = Dict(:min_to_be_happy => min_to_be_happy)
    rng = Random.Xoshiro(1234)
    model = ABM(GridSpaceAgent, space; properties, rng)
    N = grid_size[1]*grid_size[2]*grid_occupation
    for n in 1:N
        group = n < N / 2 ? 1 : 2
        agent = GridSpaceAgent(n, (1, 1), group, false)
        add_agent_single!(agent, model)
    end
    return model
end

function agent_step_gridspace!(agent, model)
    nearby_same = 0
    for neighbor in nearby_agents(agent, model)
        if agent.group == neighbor.group
            nearby_same += 1
        end
    end
    if nearby_same ≥ model.min_to_be_happy
        agent.happy = true
    else
        move_agent_single!(agent, model)
    end
    return
end

model_gridspace = initialize_gridspace()
println("Benchmarking GridSpace version")
@btime step!($model_gridspace, agent_step_gridspace!)
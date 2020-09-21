mutable struct Cell <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    status::Bool
end

"""
``` julia
game_of_life(;
    rules::Tuple = (2, 3, 3, 3),
    dims = (100, 100),
    metric = :chebyshev
)
```
Same as in [Conway's game of life](@ref).
"""
function game_of_life(;
    rules::Tuple = (2, 3, 3, 3),
    dims = (100, 100),
    metric = :chebyshev
)
    space = GridSpace(dims; metric = metric)
    properties = Dict(:rules => rules)
    model = ABM(Cell, space; properties = properties)
    idx = 1
    for x in 1:dims[1]
        for y in 1:dims[2]
            add_agent_pos!(Cell(idx, (x, y), false), model)
            idx += 1
        end
    end
    return model, dummystep, game_of_life_model_step!
end

function game_of_life_model_step!(model)
    new_status = fill(false, nagents(model))
    for agent in allagents(model)
        nlive = nlive_neighbors(agent, model)
        if agent.status == true && (nlive ≤ model.rules[4] && nlive ≥ model.rules[1])
            new_status[agent.id] = true
        elseif agent.status == false && (nlive ≥ model.rules[3] && nlive ≤ model.rules[4])
            new_status[agent.id] = true
        end
    end

    for k in keys(model.agents)
        model.agents[k].status = new_status[k]
    end
end

function nlive_neighbors(agent, model)
    neighbor_positions = nearby_positions(agent, model)
    all_neighbors = Iterators.flatten(ids_in_position(np,model) for np in neighbor_positions)
    sum(model[i].status == true for i in all_neighbors)
end

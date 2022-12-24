mutable struct DictAgent
    group::Int
    happy::Bool
end

function initialize_dict()
    model = Dict{NTuple{2, Int}, DictAgent}()
    N = grid_size[1]*grid_size[2]*grid_occupation
    for n in 1:N
        group = n < N / 2 ? 1 : 2
        pos = (rand(1:grid_size[1]), rand(1:grid_size[2]))
        while haskey(model, pos)
            pos = (rand(1:grid_size[1]), rand(1:grid_size[2]))
        end
        agent = DictAgent(group, false)
        model[pos] = agent
    end
    return model
end

function simulation_step!(model)
    # crucial to collect keys here
    filled_positions = collect(keys(model))
    for pos in filled_positions # loop over all locations on grid
        agent = model[pos]
        same = 0
        for moore_index in moore
            npos = pos .+ moore_index
            if !haskey(model, npos)
                continue
            end
            neighbor = model[npos]
            if neighbor.group == agent.group
                same += 1
            end
        end
        if same ≥ min_to_be_happy
            agent.happy = true
        else # generate new unoccupied position
            newpos = (rand(1:grid_size[1]), rand(1:grid_size[2]))
            while haskey(model, newpos) # careful here, use `newpos`, not `pos`!
                newpos = (rand(1:grid_size[1]), rand(1:grid_size[2]))
            end
            model[newpos] = agent
            delete!(model, pos)
        end
    end
end

model_dict = initialize_dict()
println("benchmarking dict-based step")
@btime simulation_step!($model_dict) setup = (model_dict = initialize_dict())
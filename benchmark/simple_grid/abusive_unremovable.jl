# This file has the most performant possible version for Schelling,
# by abusing all information we know about the model and composing it in
# a non-modular fashion. We abuse the fact that there is only 1 agent per position
# hence using 0 as and ID to represent this, and also abuse that agents don't
# die in this simulation.
# Based on https://github.com/JuliaDynamics/Agents.jl/issues/640#issuecomment-1166330815
mutable struct AbusiveUnremovableAgent
    pos::Tuple{Int,Int}
    group::Int
    happy::Bool
end

struct AbusiveUnremovableModel
    agents::Vector{AbusiveUnremovableAgent}
    space::Matrix{Int}
end

function initialize_abusiveunremovable()
    model = AbusiveUnremovableModel(AbusiveUnremovableAgent[], fill(0, grid_size...))
    N = floor(Int, grid_size[1] * grid_size[2] * grid_occupation * 0.5)

    for i in 1:2N
        grp = i <= N ? 1 : 2
        pos = (rand(1:grid_size[1]), rand(1:grid_size[2]))
        while abmspace(model)[pos...] > 0
            pos = (rand(1:grid_size[1]), rand(1:grid_size[2]))
        end

        push!(model.agents, AbusiveUnremovableAgent(pos, grp, false))
        abmspace(model)[pos...] = length(model.agents)
    end

    return model
end

function simulate_abusiveunremovable!(model)
    for i in eachindex(model.agents)
        agent = model.agents[i]
        same_count = count_nearby_same_abusiveunremovable(agent, model)
        if same_count >= min_to_be_happy
            agent.happy = true
        else
            grid_dims = size(abmspace(model))
            new_pos = (rand(1:grid_dims[1]), rand(1:grid_dims[2]))
            while abmspace(model)[new_pos...] > 0
                new_pos = (rand(1:grid_dims[1]), rand(1:grid_dims[2]))
            end
            abmspace(model)[agent.pos...] = 0
            agent.pos = new_pos
            abmspace(model)[agent.pos...] = i
        end
    end
end

function count_nearby_same_abusiveunremovable(agent, model)
    same_count = 0
    for offset in moore
        new_pos = agent.pos .+ offset
        if checkbounds(Bool, abmspace(model), new_pos...) && abmspace(model)[new_pos...] != 0
            if model.agents[abmspace(model)[new_pos...]].group == agent.group
                same_count += 1
            end
        end
    end
    return same_count
end

model_abusiveunremovable = initialize_abusiveunremovable()
println("Benchmarking abusive unremovable version")
@btime simulate_abusiveunremovable!($model_abusiveunremovable) setup = (model_abusiveunremovable = initialize_abusiveunremovable())
println("Benchmarking abusive unremovable version: count nearby same")
model_abusiveunremovable = initialize_abusiveunremovable()
@btime count_nearby_same_abusiveunremovable(agent, model_abusiveunremovable) setup = (agent = rand(model_abusiveunremovable.agents))

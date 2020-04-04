using Agents
using BenchmarkTools
using Random
using StatsBase: mean

mutable struct Agent1 <: AbstractAgent
  id::Int
  weight::Float64
end
function init1()
    Random.seed!(267)
    model = ABM(Agent1;
                properties = Dict(:year => 0, :tick => 0, :flag => false))
    for a in 1:1000
        add_agent!(model, rand())
    end
    return model
end
function as1!(agent, model)
    if rand() < 0.1
        agent.weight += 0.05
    end
    if model.tick%365 == 0
        agent.weight *= 2
    end
end
function ms1!(model)
    model.tick += 1
    model.flag = rand(Bool)
    if model.tick%365 == 0
        model.year += 1
    end
end

using Agents
using BenchmarkTools
using Random
using StatsBase: mean

mutable struct Agent1 <: AbstractAgent
  id::Int
  weight::Float64
  type::String
end
function init1()
    Random.seed!(267)
    model = ABM(Agent1;
                properties = Dict(:year => 0, :tick => 0, :flag => false))
    for a in 1:1000
        add_agent!(model, rand(), randstring(4))
    end
    return model
end
function as1!(agent, model)
    nothing
end
function ms1!(model)
    nothing
end

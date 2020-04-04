using Agents
using BenchmarkTools
using Random

mutable struct Agent3 <: AbstractAgent
  id::Int
  weight::Float64
end

function initialize()
    Random.seed!(267)
    model = ABM(Agent3; properties = Dict(:year => 0, :tick => 0, :flag => false))
    for a in 1:1000
        add_agent!(model, rand())
    end
    return model
end

function agent_step!(agent, model)
    if rand() < 0.1
        agent.weight += 0.05
    end
    if model.tick%365 == 0
        agent.weight *= 2
    end
end
function model_step!(model)
    model.tick += 1
    model.flag = rand(Bool)
    if model.tick%365 == 0
        model.year += 1
    end
end

a = @benchmark run!(
    model, agent_step!, model_step!, 365*10;
    model_properties = [:flag, :year], agent_properties = [(:weight, mean)]
    ) setup=(model = initialize())
display(a)
# Initial
# BenchmarkTools.Trial:
#  memory estimate:  607.65 MiB
#  allocs estimate:  5481299
#  --------------
#  minimum time:     1.016 s (3.04% GC)
#  median time:      1.020 s (3.03% GC)
#  mean time:        1.020 s (2.99% GC)
#  maximum time:     1.024 s (3.04% GC)
#  --------------
#  samples:          5
#  evals/sample:     1%
#
# Swapping to append!
# BenchmarkTools.Trial:
#  memory estimate:  356.15 MiB
#  allocs estimate:  4741603
#  --------------
#  minimum time:     709.798 ms (2.35% GC)
#  median time:      746.618 ms (2.48% GC)
#  mean time:        737.661 ms (2.48% GC)
#  maximum time:     755.366 ms (2.46% GC)
#  --------------
#  samples:          7
#  evals/sample:     1
#
#  With initialisation
#BenchmarkTools.Trial:
#  memory estimate:  15.33 MiB
#  allocs estimate:  181639
#  --------------
#  minimum time:     216.462 ms (0.00% GC)
#  median time:      221.095 ms (0.00% GC)
#  mean time:        221.368 ms (0.50% GC)
#  maximum time:     232.810 ms (0.00% GC)
#  --------------
#  samples:          23
#  evals/sample:     1BenchmarkTools.Trial:
#  memory estimate:  49.36 KiB
#  allocs estimate:  1032
#  --------------
#  minimum time:     60.164 μs (0.00% GC)
#  median time:      64.805 μs (0.00% GC)
#  mean time:        70.089 μs (2.56% GC)
#  maximum time:     3.041 ms (96.93% GC)
#  --------------
#  samples:          1643
#  evals/sample:     1%

using Agents, Test
using StableRNGs
using BenchmarkTools

extent = (1.0, 1.0)
spacing = 0.1
r = 0.1
space = ContinuousSpace(extent, spacing)
@agent struct Agent(ContinuousAgent{2,Float64})
end
model = StandardABM(Agent, space; rng = StableRNG(42))

# fill with random agents
N = 1000
for i in 1:N
    add_agent!(model, (0.0, 0.0))
end

function count_nearby_same(agent, model)
    nearby_same = 0
    for neighbor in nearby_agents(agent, model, r)
        nearby_same += neighbor.id
    end
    return nearby_same
end
function count_nearby_same_exact(agent, model)
    nearby_same = 0
    for neighbor in nearby_agents_exact(agent, model, r)
        nearby_same += neighbor.id
    end
    return nearby_same
end

println("Continuous space count nearby ids, spacing=$spacing, r=$r, inexact")
@btime count_nearby_same(agent, $model) setup = (agent = random_agent($model))
println("Continuous space count nearby ids, spacing=$spacing, r=$r, exact")
@btime count_nearby_same_exact(agent, $model) setup = (agent = random_agent($model))

#= Results
# Current state
Continuous space count nearby ids, spacing=0.05, r=0.1, inexact
  839.130 ns (2 allocations: 288 bytes)
Continuous space count nearby ids, spacing=0.05, r=0.1, exact
  4.243 μs (60 allocations: 5.56 KiB)

  Continuous space count nearby ids, spacing=0.1, r=0.1, inexact
  1.220 μs (2 allocations: 288 bytes)
Continuous space count nearby ids, spacing=0.1, r=0.1, exact
  4.843 μs (58 allocations: 5.22 KiB)


# master
Continuous space count nearby ids, spacing=0.05, r=0.1, inexact
  3.612 μs (71 allocations: 4.91 KiB)
Continuous space count nearby ids, spacing=0.05, r=0.1, exact
  10.600 μs (164 allocations: 30.15 KiB)

Continuous space count nearby ids, spacing=0.1, r=0.1, inexact
  5.900 μs (118 allocations: 8.05 KiB)
Continuous space count nearby ids, spacing=0.1, r=0.1, exact
  10.300 μs (218 allocations: 32.88 KiB)
  =#

using Agents, Test
using StableRNGs
using BenchmarkTools

extent = (1.0, 1.0)
spacing = 0.1
r = 0.1
space = ContinuousSpace(extent; spacing)
@agent Agent ContinuousAgent{2} begin end
model = ABM(Agent, space; rng = StableRNG(42))

# fill with random agents
N = 1000
for i in 1:N
    add_agent!(model, (0.0, 0.0))
end

function count_nearby_same(agent, model)
    nearby_same = 0
    for neighbor in nearby_agents(agent, model)
        nearby_same += neighbor.id
    end
    return nearby_same
end
function count_nearby_same_exact(agent, model)
    nearby_same = 0
    for neighbor in nearby_agents_exact(agent, model)
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
  149.500 μs (0 allocations: 0 bytes)
Continuous space count nearby ids, spacing=0.05, r=0.1, exact
  1.117 ms (25761 allocations: 2.48 MiB)

Continuous space count nearby ids, spacing=0.1, r=0.1, inexact
  132.500 μs (0 allocations: 0 bytes)
Continuous space count nearby ids, spacing=0.1, r=0.1, exact
  943.900 μs (24154 allocations: 2.27 MiB)

# master

=#
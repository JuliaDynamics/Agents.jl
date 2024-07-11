# This file compares approaching multi-agent models in two ways:
# 1) using different Types to represent different agents. This leads to type
# instabilities.
# 2) using @sumtype to enclose all types in a single one. This removes type
# instabilities.

# The result is that (2) is much faster.

################### DEFINITION 1 ###############
using Agents, Random, BenchmarkTools

@agent struct GridAgentOne(GridAgent{2})
    one::Float64
    two::Bool
    three::Int
end

@agent struct GridAgentTwo(GridAgent{2})
    one::Float64
    two::Bool
    four::Float64
end

@agent struct GridAgentThree(GridAgent{2})
    one::Float64
    two::Bool
    five::Bool
end

@agent struct GridAgentFour(GridAgent{2})
    one::Float64
    two::Bool
    six::Int16
end

@agent struct GridAgentFive(GridAgent{2})
    one::Float64
    two::Bool
    seven::Int32
end

@agent struct GridAgentSix(GridAgent{2})
    one::Float64
    two::Bool
    eight::Int64
end

const types = Union{GridAgentOne, GridAgentTwo, GridAgentThree, GridAgentFour, GridAgentFive, GridAgentSix}

agent_step!(agent::GridAgentOne, model1) = randomwalk!(agent, model1)
function agent_step!(agent::GridAgentTwo, model1)
    agent.one += rand(abmrng(model1))
    agent.two = rand(abmrng(model1), Bool)
end
function agent_step!(agent::GridAgentThree, model1)
    if any(a-> a isa GridAgentTwo, nearby_agents(agent, model1))
        agent.two = true
        randomwalk!(agent, model1)
    end
end
function agent_step!(agent::GridAgentFour, model1)
    agent.one += sum(a.one for a in nearby_agents(agent, model1))
end
function agent_step!(agent::GridAgentFive, model1)
    targets = filter!(a->a.one > 1.0, collect(types, nearby_agents(agent, model1, 3)))
    if !isempty(targets)
        idx = argmax(map(t->euclidean_distance(agent, t, model1), targets))
        farthest = targets[idx]
        walk!(agent, sign.(farthest.pos .- agent.pos), model1)
    end
end
function agent_step!(agent::GridAgentSix, model1)
    agent.eight += sum(rand(abmrng(model1), (0, 1)) for a in nearby_agents(agent, model1))
end

model1 = StandardABM(
    Union{GridAgentOne,GridAgentTwo,GridAgentThree,GridAgentFour,GridAgentFive,GridAgentSix},
    GridSpace((15, 15));
    agent_step!,
    warn = false,
    rng = MersenneTwister(42),
    scheduler = Schedulers.Randomly(),
)

for i in 1:500
    add_agent!(GridAgentOne, model1, rand(abmrng(model1)), rand(abmrng(model1), Bool), i)
    add_agent!(GridAgentTwo, model1, rand(abmrng(model1)), rand(abmrng(model1), Bool), Float64(i))
    add_agent!(GridAgentThree, model1, rand(abmrng(model1)), rand(abmrng(model1), Bool), true)
    add_agent!(GridAgentFour, model1, rand(abmrng(model1)), rand(abmrng(model1), Bool), Int16(i))
    add_agent!(GridAgentFive, model1, rand(abmrng(model1)), rand(abmrng(model1), Bool), Int32(i))
    add_agent!(GridAgentSix, model1, rand(abmrng(model1)), rand(abmrng(model1), Bool), i)
end

################### DEFINITION 2 ###############

using DynamicSumTypes

agent_step!(agent, model2) = agent_step!(agent, model2, variant(agent))

agent_step!(agent, model2, ::GridAgentOne) = randomwalk!(agent, model2)
function agent_step!(agent, model2, ::GridAgentTwo)
    agent.one += rand(abmrng(model2))
    agent.two = rand(abmrng(model2), Bool)
end
function agent_step!(agent, model2, ::GridAgentThree)
    if any(a-> variant(a) isa GridAgentTwo, nearby_agents(agent, model2))
        agent.two = true
        randomwalk!(agent, model2)
    end
end
function agent_step!(agent, model2, ::GridAgentFour)
    agent.one += sum(a.one for a in nearby_agents(agent, model2))
end
function agent_step!(agent, model2, ::GridAgentFive)
    targets = filter!(a->a.one > 1.0, collect(GridAgentAll, nearby_agents(agent, model2, 3)))
    if !isempty(targets)
        idx = argmax(map(t->euclidean_distance(agent, t, model2), targets))
        farthest = targets[idx]
        walk!(agent, sign.(farthest.pos .- agent.pos), model2)
    end
end
function agent_step!(agent, model2, ::GridAgentSix)
    agent.eight += sum(rand(abmrng(model2), (0, 1)) for a in nearby_agents(agent, model2))
end

@sumtype GridAgentAll(
    GridAgentOne, GridAgentTwo, GridAgentThree, GridAgentFour, GridAgentFive, GridAgentSix
) <: AbstractAgent

model2 = StandardABM(
    GridAgentAll,
    GridSpace((15, 15));
    agent_step!,
    rng = MersenneTwister(42),
    scheduler = Schedulers.Randomly(),
)

for i in 1:500
    agent = GridAgentAll(GridAgentOne(model2, random_position(model2), rand(abmrng(model2)), rand(abmrng(model2), Bool), i))
    add_agent_own_pos!(agent, model2)
    agent = GridAgentAll(GridAgentTwo(model2, random_position(model2), rand(abmrng(model2)), rand(abmrng(model2), Bool), Float64(i)))
    add_agent_own_pos!(agent, model2)
    agent = GridAgentAll(GridAgentThree(model2, random_position(model2), rand(abmrng(model2)), rand(abmrng(model2), Bool), true))
    add_agent_own_pos!(agent, model2)
    agent = GridAgentAll(GridAgentFour(model2, random_position(model2), rand(abmrng(model2)), rand(abmrng(model2), Bool), Int16(i)))
    add_agent_own_pos!(agent, model2)
    agent = GridAgentAll(GridAgentFive(model2, random_position(model2), rand(abmrng(model2)), rand(abmrng(model2), Bool), Int32(i)))
    add_agent_own_pos!(agent, model2)
    agent = GridAgentAll(GridAgentSix(model2, random_position(model2), rand(abmrng(model2)), rand(abmrng(model2), Bool), i))
    add_agent_own_pos!(agent, model2)
end

################### Benchmarks ###############

t1 = @belapsed step!($model1, 50)
t2 = @belapsed step!($model2, 50)

# Results:
# multiple types: 1.849 s (34267900 allocations: 1.96 GiB)
# @sumtype: 545.119 ms (22952850 allocations: 965.93 MiB)

m1 = Base.summarysize(model1)
m2 = Base.summarysize(model2)

# Results:
# multiple types: 543.496 KiB
# @sumtype: 546.360 KiB

println("Time to step the model with multiple types: $(t1) s")
println("Time to step the model with @sumtype: $(t2) s")
println("Memory occupied by the model with multiple types: $(m1/1000) Kib")
println("Memory occupied by the model with @sumtype: $(m2/1000) Kib")

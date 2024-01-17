# This file compares approaching multi-agent models in two ways:
# 1) using different Types to represent different agents. This leads to type
# stability within `step!`.
# 2) using a single type with some extra property `type` or `kind`, and then do
# an `if`-based branching on this type to dispatch to different functions.

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
    six::Int8
end

@agent struct GridAgentFive(GridAgent{2})
    one::Float64
    two::Bool
    seven::Int32
end

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
    targets = filter!(a->a.one > 0.8, collect(nearby_agents(agent, model1, 3)))
    idx = argmax(map(t->euclidean_distance(agent, t, model1), targets))
    farthest = targets[idx]
    walk!(agent, sign.(farthest.pos .- agent.pos), model1)
end

model1 = StandardABM(
    Union{GridAgentOne,GridAgentTwo,GridAgentThree,GridAgentFour,GridAgentFive},
    GridSpace((15, 15));
    agent_step!,
    warn = false,
    rng = MersenneTwister(42),
    scheduler = Schedulers.Randomly(),
)

for i in 1:50
    add_agent!(GridAgentOne, model1, rand(abmrng(model1)), rand(abmrng(model1), Bool), i)
    add_agent!(GridAgentTwo, model1, rand(abmrng(model1)), rand(abmrng(model1), Bool), Float64(i))
    add_agent!(GridAgentThree, model1, rand(abmrng(model1)), rand(abmrng(model1), Bool), true)
    add_agent!(GridAgentFour, model1, rand(abmrng(model1)), rand(abmrng(model1), Bool), Int8(i))
    add_agent!(GridAgentFive, model1, rand(abmrng(model1)), rand(abmrng(model1), Bool), Int32(i))
end

################### DEFINITION 2 ###############

@multiagent struct GridAgentAll(GridAgent{2})
    @agent struct GridAgentOne
        one::Float64
        two::Bool
        three::Int
    end
    @agent struct GridAgentTwo
        one::Float64
        two::Bool
        four::Float64
    end
    @agent struct GridAgentThree
        one::Float64
        two::Bool
        five::Bool
    end
    @agent struct GridAgentFour
        one::Float64
        two::Bool
        six::Int8
    end
    @agent struct GridAgentFive
        one::Float64
        two::Bool
        seven::Int32
    end
end

function agent_step!(agent::GridAgentAll, model2)
    if agent.type == :gridagentone
        agent_step_one!(agent, model2)
    elseif agent.type == :gridagenttwo
        agent_step_two!(agent, model2)
    elseif agent.type == :gridagentthree
        agent_step_three!(agent, model2)
    elseif agent.type == :gridagentfour
        agent_step_four!(agent, model2)
    else
        agent_step_five!(agent, model2)
    end
end
agent_step_one!(agent, model2) = randomwalk!(agent, model2)
function agent_step_two!(agent, model2)
    agent.one += rand(abmrng(model2))
    agent.two = rand(abmrng(model2), Bool)
end
function agent_step_three!(agent, model2)
    if any(a-> a.type == :two, nearby_agents(agent, model2))
        agent.two = true
        randomwalk!(agent, model2)
    end
end
function agent_step_four!(agent, model2)
    agent.one += sum(a.one for a in nearby_agents(agent, model2))
end
function agent_step_five!(agent, model2)
    targets = filter!(a->a.one > 1.0, collect(nearby_agents(agent, model2, 3)))
    if !isempty(targets)
        idx = argmax(map(t->euclidean_distance(agent, t, model2), targets))
        farthest = targets[idx]
        walk!(agent, sign.(farthest.pos .- agent.pos), model2)
    end
end

model2 = StandardABM(
    GridAgentAll,
    GridSpace((15, 15));
    agent_step!,
    rng = MersenneTwister(42),
    scheduler = Schedulers.Randomly(),
)

for i in 1:50
    add_agent!(GridAgentOne, model2, rand(abmrng(model2)), rand(abmrng(model2), Bool), i)
    add_agent!(GridAgentTwo, model2, rand(abmrng(model2)), rand(abmrng(model2), Bool), Float64(i))
    add_agent!(GridAgentThree, model2, rand(abmrng(model2)), rand(abmrng(model2), Bool), true)
    add_agent!(GridAgentFour, model2, rand(abmrng(model2)), rand(abmrng(model2), Bool), Int8(i))
    add_agent!(GridAgentFive, model2, rand(abmrng(model2)), rand(abmrng(model2), Bool), Int32(i))
end

################### Benchmarks ###############

@btime step!($model1, 500)
@btime step!($model2, 500)

# Results:
# 303.112 ms (4214469 allocations: 314.92 MiB)
# 62.311 ms (2202340 allocations: 119.68 MiB)

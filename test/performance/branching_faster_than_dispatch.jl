# This file compares approaching multi-agent models in two ways:
# 1) using different Types to represent different agents. This leads to type
# stability within `step!`.
# 2) using a single type with some extra property `type` or `kind`, and then do
# an `if`-based branching on this type to dispatch to different functions.

# The result is that (2) is much faster.

################### DEFINITION 1 ###############
using Agents, Random, BenchmarkTools

@agent struct GridAgentOne <: AbstractAgent
    id::Int
    pos::Dims{2}
    one::Float64
    two::Bool
end

@agent struct GridAgentTwo(GridAgent{2})
    one::Float64
    two::Bool
end

@agent struct GridAgentThree(GridAgent{2})
    one::Float64
    two::Bool
end

@agent struct GridAgentFour(GridAgent{2})
    one::Float64
    two::Bool
end

@agent struct GridAgentFive(GridAgent{2})
    one::Float64
    two::Bool
end

model1 = ABM(
    Union{GridAgentOne,GridAgentTwo,GridAgentThree,GridAgentFour,GridAgentFive},
    GridSpace((15, 15));
    warn = false,
    rng = MersenneTwister(42),
    scheduler = Schedulers.randomly,
)

for _ in 1:50
    add_agent!(GridAgentOne, model1, rand(abmrng(model1)), rand(abmrng(model1), Bool))
    add_agent!(GridAgentTwo, model1, rand(abmrng(model1)), rand(abmrng(model1), Bool))
    add_agent!(GridAgentThree, model1, rand(abmrng(model1)), rand(abmrng(model1), Bool))
    add_agent!(GridAgentFour, model1, rand(abmrng(model1)), rand(abmrng(model1), Bool))
    add_agent!(GridAgentFive, model1, rand(abmrng(model1)), rand(abmrng(model1), Bool))
end

agent_step!(agent::GridAgentOne, model1) = walk!(agent, rand, model1)
function agent_step!(agent::GridAgentTwo, model1)
    agent.one += rand(abmrng(model1))
    agent.two = rand(abmrng(model1), Bool)
end
function agent_step!(agent::GridAgentThree, model1)
    if any(a-> a isa GridAgentTwo, nearby_agents(agent, model1))
        agent.two = true
        walk!(agent, rand, model1)
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

################### DEFINITION 2 ###############

@agent struct GridAgentAll(GridAgent{2})
    one::Float64
    two::Bool
    type::Symbol
end

model2 = ABM(
    GridAgentAll,
    GridSpace((15, 15));
    rng = MersenneTwister(42),
    scheduler = Schedulers.randomly,
)

for _ in 1:50
    add_agent!(GridAgentAll, model2, rand(abmrng(model2)), rand(abmrng(model2), Bool), :one)
    add_agent!(GridAgentAll, model2, rand(abmrng(model2)), rand(abmrng(model2), Bool), :two)
    add_agent!(GridAgentAll, model2, rand(abmrng(model2)), rand(abmrng(model2), Bool), :three)
    add_agent!(GridAgentAll, model2, rand(abmrng(model2)), rand(abmrng(model2), Bool), :four)
    add_agent!(GridAgentAll, model2, rand(abmrng(model2)), rand(abmrng(model2), Bool), :five)
end

function agent_step!(agent::GridAgentAll, model2)
    if agent.type == :one
        agent_step_one!(agent, model2)
    elseif agent.type == :two
        agent_step_two!(agent, model2)
    elseif agent.type == :three
        agent_step_three!(agent, model2)
    elseif agent.type == :four
        agent_step_four!(agent, model2)
    else
        agent_step_five!(agent, model2)
    end
end
agent_step_one!(agent, model2) = walk!(agent, rand, model2)
function agent_step_two!(agent, model2)
    agent.one += rand(abmrng(model2))
    agent.two = rand(abmrng(model2), Bool)
end
function agent_step_three!(agent, model2)
    if any(a-> a.type == :two, nearby_agents(agent, model2))
        agent.two = true
        walk!(agent, rand, model2)
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

################### Benchmarks ###############

@btime step!($model1, agent_step!, dummystep, 500)
@btime step!($model2, agent_step!, dummystep, 500)

# Results:
# 718.589 ms (11581560 allocations: 704.26 MiB)
# 141.673 ms (2292318  allocations: 149.54 MiB)

export nagents, AbstractAgent, ABM,
random_activation, as_added, partial_activation

"""
All agents must be a mutable subtype of `AbstractAgent`.
Your agent type **must have** at least the `pos` field, i.e.:
```julia
mutable struct MyAgent{P} <: AbstractAgent
    pos::P
end
```
Only for grid spaces, `pos` can be an `NTuple`. For arbitrary graph spaces
it must always be an integer (the graph node number).

Your agent type may have other additional fields relevant to your system,
for example variable quantities like "status" or other "counters".
"""
abstract type AbstractAgent end

struct AgentBasedModel{A<:AbstractAgent, S<:AbstractSpace, F, P}
    agents::Vector{Union{A, Missing}}
    space::S
    scheduler::F
    properties::P
end
const ABM = AgentBasedModel

"""
    AgentBasedModel(agents, space[, scheduler, properties])
Create an agent based model from the given agents (one or many),
the `space` (from [`Space`](@ref)).

Optionally provide a `scheduler` that creates the order with which agents
are activated in the model, and `properties` (a dictionary of key-type `Symbol`)
for additional model-level properties.
"""
function AgentBasedModel(
        agent::A, space::S,
        scheduler::F = as_added, properties::P = nothing
        ) where {A<:AbstractAgent, S<:AbstractSpace, F, P}
    agents = Union{A, Missing}[agent]
    return ABM{A, S, F, P}(agents, space, scheduler, properties)
end



"""
  nagents(model::ABM)

Return the number of (alive) agents.
"""
nagents(model::ABM) = count(!ismissing, model.agents)

"""
    as_added(model::ABM)

Activate agents at each step in the same order as they have been added to the model.
"""
as_added(model::ABM) = skipmissing(model.agents)

"""
    random_activation(model::ABM)

Activate agents once per step in a random order.
"""
random_activation(model::ABM) = randomskipmissing(model.agents)

struct RandomSkipMissing{A}
    agents::A
    n::Int
    perm::Vector{Int}
end
function RandomSkipMissing(agents::A) where {A}
    n = length(agents)
    perm = randperm(n)
    return RandomSkipMissing{A}(agents, n, perm)
end
function Base.iterate(r::RandomSkipMissing, s = 1)
    s > r.n && return nothing
    while @inbounds ismissing(r.agents[r.perm[s]])
        s += 1
        s > r.n && return nothing
    end
    return @inbounds (r.agents[r.perm[s]], s+1)
end

"""
    partial_activation(model::ABM)

At each step, activate only `activation_prob` number of randomly chosen of individuals
with a `activation_prob` probability.
`activation_prob` must be a field in the model and between 0 and 1.
"""
function partial_activation(model::ABM)
    error("update me!")
  agentnum = nagents(model)
  return randsubseq(1:agentnum, model.activation_prob)
end

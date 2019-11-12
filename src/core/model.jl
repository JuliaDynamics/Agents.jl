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
    agents::Vector{A}
    space::S
    scheduler::F
    properties::P
end
const ABM = AgentBasedModel

"""
    AgentBasedModel(agent, space[, scheduler, properties])
Create an agent based model from the given agent (one, only for type information),
and the `space` (from [`Space`](@ref)).
`ABM` is equivalent with `AgentBasedModel`.

Optionally provide a `scheduler` that creates the order with which agents
are activated in the model, and `properties` (a dictionary of key-type `Symbol`)
for additional model-level properties.
"""
function AgentBasedModel(
        agent::A, space::S,
        scheduler::F = as_added, properties::P = nothing
        ) where {A<:AbstractAgent, S<:AbstractSpace, F, P}
    agents = A[]
    return ABM{A, S, F, P}(agents, space, scheduler, properties)
end


"""
  nagents(model::AbstractModel)
Return the number of agents.
"""
nagents(model::AbstractModel) = length(model.agents)

"""
    as_added(model::AbstractModel)
Activate agents at each step in the same order as they have been added to the model.
"""
function as_added(model::AbstractModel)
  agent_ids = [i.id for i in 1:length(model.agents)]
  return sortperm(agent_ids)
end

"""
    random_activation(model::AbstractModel)
Activate agents once per step in a random order.
"""
function random_activation(model::AbstractModel)
  order = shuffle(1:length(model.agents))
end

"""
    partial_activation(model::AbstractModel)
At each step, activate only `activation_prob` number of randomly chosen of individuals
with a `activation_prob` probability.
`activation_prob` must be a field in the model and between 0 and 1.
"""
function partial_activation(model::AbstractModel)
  agentnum = nagents(model)
  return randsubseq(1:agentnum, model.activation_prob)
end

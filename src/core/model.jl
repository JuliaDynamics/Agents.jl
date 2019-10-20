export nagents, AbstractAgent, AbstractModel,
random_activation, as_added, partial_activation

"""
All agents must be a mutable subtype of `AbstractAgent`.
Your agent type **must have** the following fields: `id`, `pos`.

For grid spaces, `pos` should be an `NTuple`, while for graph spaces it should be
an integer.

Your agent type may have other additional fields relevant to your system.
"""
abstract type AbstractAgent end

"""
All models must be a subtype of `AbstractModel`.
Your model type **must have** the following fields:
```julia
mutable struct MyModel{F, S} <: AbstractModel
  scheduler::F
  space::S
  agents::Vector{Int}  # a list of agents ids
end
```
`scheduler` can be from Agents.jl ([`random_activation`](@ref), [`as_added`](@ref),
[`partial_activation`](@ref)), or your own function.
Your model type may have other additional fields relevant to your system.
"""
abstract type AbstractModel end

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

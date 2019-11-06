export nagents, AbstractAgent, AbstractModel,
random_activation, as_added, partial_activation

"""
All agents must be a mutable subtype of `AbstractAgent`.
Your agent type **must have** the following fields:
```julia
mutable struct MyAgent{P} <: AbstractAgent
    id::Int
    pos::P
end
```
Only for grid spaces, `pos` can be an `NTuple`. For arbitrary graph spaces
it must always be an integer (the graph node number).

Your agent type may have other additional fields relevant to your system,
for example variable quantities like "status" or other "counters".
"""
abstract type AbstractAgent end

"""
All models must be a subtype of `AbstractModel`.
Your model type **must have** the following fields:
```julia
struct MyModel{F, S, A} <: AbstractModel
    scheduler::F
    space::S
    agents::Vector{A}  # a vector of agents (of type `A`)
end
```
`scheduler` is a function that defines the order with which agents will activate
at each step. The function should accept the model object as its input and return a list
of agent indices. You can use [`random_activation`](@ref), [`as_added`](@ref),
[`partial_activation`](@ref) from Agents.jl, or your own function.

Your model type may have other additional fields relevant to your system,
for example parameter values.
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

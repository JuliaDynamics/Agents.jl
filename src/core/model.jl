export nagents, AbstractAgent, ABM, AgentBasedModel,
random_activation, as_added, partial_activation

abstract type AbstractSpace end

"""
All agents must be a mutable subtype of `AbstractAgent`.
Your agent type **must have** at least the `id` field, and if there is a space structure, the `pos` field, i.e.:
```julia
mutable struct MyAgent{P} <: AbstractAgent
    id::P
    pos::P
end
```
Only for grid spaces, `pos` can be an `NTuple`. For arbitrary graph spaces
it must always be an integer (the graph node number).

Your agent type may have other additional fields relevant to your system,
for example variable quantities like "status" or other "counters".
"""
abstract type AbstractAgent end

SpaceType=Union{Nothing, AbstractSpace}
struct AgentBasedModel{A<:AbstractAgent, S<:SpaceType, F, P}
    agents::Dict{Int,A}
    space::S
    scheduler::F
    properties::P
end
const ABM = AgentBasedModel

"""
    AgentBasedModel(agent_type [, space]; scheduler, properties)
Create an agent based model from the given agent type,
and the `space` (from [`Space`](@ref)).
`ABM` is equivalent with `AgentBasedModel`.

`space` can be omitted, in which it will equal to `nothing`.
This means that all agents are virtualy in one node and have no spatial structure.
If space is omitted, functions that fascilitate agent-space interactions will not work.

Optionally provide a `scheduler` that creates the order with which agents
are activated in the model, and `properties`
for additional model-level properties.
This is accessed as `model.properties` for later use.
"""
function AgentBasedModel(
        ::Type{A}, space::S = nothing;
        scheduler::F = as_added, properties::P = nothing
        ) where {A<:AbstractAgent, S<:SpaceType, F, P}
    agents = Dict{Int, A}()
    return ABM{A, S, F, P}(agents, space, scheduler, properties)
end

function Base.show(io::IO, abm::ABM{A}) where {A}
    s = "AgentBasedModel with $(nagents(abm)) agents of type $A"
    if abm.space == nothing
        s*= "\n no space"
    else
        s*= "\n space: $(nameof(typeof(abm.space))) with $(nv(abm)) nodes and $(ne(abm)) edges"
    end
    s*= "\n scheduler: $(nameof(abm.scheduler))"
    print(io, s)
    if abm.properties ≠ nothing
        print(io, "\n properties: ", abm.properties)
    end
end


"""
    nagents(model::ABM)
Return the number of agents in the `model`.
"""
nagents(model::ABM) = length(model.agents)

"""
    as_added(model::ABM)
Activate agents at each step in the same order as they have been added to the model.
"""
function as_added(model::ABM)
  agent_ids = sort(collect(keys(model.agents)))
  return agent_ids
end

"""
    random_activation(model::ABM)
Activate agents once per step in a random order.
"""
function random_activation(model::ABM)
  order = shuffle(collect(keys(model.agents)))
end

"""
    partial_activation(model::ABM)
At each step, activate only `activation_prob` number of randomly chosen of individuals
with a `activation_prob` probability.
`activation_prob` must be a field in the model and between 0 and 1.
"""
function partial_activation(model::ABM)
  agentnum = nagents(model)
  return randsubseq(1:agentnum, model.activation_prob)
end

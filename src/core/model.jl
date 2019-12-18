export nagents, AbstractAgent, ABM, AgentBasedModel,
random_activation, by_id, fastest, partial_activation, random_agent,
property_activation, pos_vertex

abstract type AbstractSpace end

"""
All agents must be a mutable subtype of `AbstractAgent`.
Your agent type **must have** at least the `id` field, and if there is a
space structure the `pos` field, (fields are expected in this order)
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

function correct_pos_type(n, model)
    if typeof(model.space) <: GraphSpace
        return coord2vertex(n, model)
    elseif typeof(model.space) <: GridSpace
        return vertex2coord(n, model)
    end
end

function pos_vertex(n, model)
    if typeof(model.space) <: GraphSpace
        return n
    elseif typeof(model.space) <: GridSpace
        return coord2vertex(n, model)
    end
end

SpaceType=Union{Nothing, AbstractSpace}
struct AgentBasedModel{A<:AbstractAgent, S<:SpaceType, F, P}
    agents::Dict{Int,A}
    space::S
    scheduler::F
    properties::P
end
const ABM = AgentBasedModel
agenttype(::ABM{A}) where {A} = A

"""
    AgentBasedModel(agent_type [, space]; scheduler, properties)
Create an agent based model from the given agent type,
and the `space` (from [`Space`](@ref)).
`ABM` is equivalent with `AgentBasedModel`.
The agents are stored in a dictionary `model.agents`, where the keys are the
agent IDs, while the values are the agents themselves.
It is recommended however to use [`id2agent`](@ref) to get an agent.

`space` can be omitted, in which it will equal to `nothing`.
This means that all agents are virtualy in one node and have no spatial structure.
If space is omitted, some functions that fascilitate agent-space interactions will not work.

Optionally provide a `scheduler` that creates the order with which agents
are activated in the model, and `properties`
for additional model-level properties.
This is accessed as `model.properties` for later use.
"""
function AgentBasedModel(
        ::Type{A}, space::S = nothing;
        scheduler::F = fastest, properties::P = nothing
        ) where {A<:AbstractAgent, S<:SpaceType, F, P}
    agents = Dict{Int, A}()
    return ABM{A, S, F, P}(agents, space, scheduler, properties)
end

function Base.show(io::IO, abm::ABM{A}) where {A}
    s = "AgentBasedModel with $(nagents(abm)) agents of type $(nameof(A))"
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
    random_agent(model)
Return a random agent from the model.
"""
random_agent(model) = model.agents[rand(keys(model.agents))]

"""
    nagents(model::ABM)
Return the number of agents in the `model`.
"""
nagents(model::ABM) = length(model.agents)


####################################
# Schedulers
####################################
"""
    fastest
Activate all agents once per step in the order dictated by the agent's container,
which is arbitrary (the keys sequence of a dictionary).
This is the fastest way to activate all agents once per step.
"""
fastest(model) = keys(model.agents)

"""
    by_id
Activate agents at each step according to their id.
"""
function by_id(model::ABM)
  agent_ids = sort(collect(keys(model.agents)))
  return agent_ids
end

@deprecate as_added by_id

"""
    random_activation
Activate agents once per step in a random order.
Different random ordering is used at each different step.
"""
function random_activation(model::ABM)
  order = shuffle(collect(keys(model.agents)))
end

"""
    partial_activation(p)
At each step, activate only `p` percentage of randomly chosen agents.
"""
function partial_activation(p::Real)
    function partial(model::ABM{A, S, F, P}) where {A, S, F, P}
        ids = collect(keys(model.agents))
        return randsubseq(ids, p)
    end
    return partial
end

"""
    property_activation(property)
At each step, activate the agents in an order dictated by their `property`,
with agents with greater `property` acting first. `property` is a `Symbol`, which
just dictates which field the agents to compare.
"""
function property_activation(p::Symbol)
    function by_property(model::ABM{A, S, F, P}) where {A, S, F, P}
        ids = collect(keys(model.agents))
        properties = [getproperty(model.agents[id], p) for id in ids]
        s = sortperm(properties)
        return ids[s]
    end
end

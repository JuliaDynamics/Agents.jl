export nagents, AbstractAgent, ABM, AgentBasedModel,
random_activation, by_id, fastest, partial_activation, random_agent,
property_activation, allagents

abstract type AbstractSpace end

"""
All agents must be a mutable subtype of `AbstractAgent`.
Your agent type **must have** the `id` field as first field.
Depending on the space structure there might be a `pos` field of appropriate type
and a `vel` field of appropriate type.

Your agent type may have other additional fields relevant to your system,
for example variable quantities like "status" or other "counters".

## Examples
Imagine agents who have extra properties `weight, happy`. For a [`GraphSpace`](@ref)
we would define them like
```julia
mutable struct ExampleAgent <: AbstractAgent
    id::Int
    pos::Int
    weight::Float64
    happy::Bool
end
```
while for e.g. a [`ContinuousSpace`](@ref) we would use
```julia
mutable struct ExampleAgent <: AbstractAgent
    id::Int
    pos::NTuple{2, Float64}
    vel::NTuple{2, Float64}
    weight::Float64
    happy::Bool
end
```
"""
abstract type AbstractAgent end

function correct_pos_type(n, model)
    if typeof(model.space) <: GraphSpace
        return coord2vertex(n, model)
    elseif typeof(model.space) <: GridSpace
        return vertex2coord(n, model)
    end
end

SpaceType=Union{Nothing, AbstractSpace}
struct AgentBasedModel{A<:AbstractAgent, S<:SpaceType, F, P}
    agents::Dict{Int,A}
    space::S
    scheduler::F
    properties::P
end
agenttype(::AgentBasedModel{A}) where {A} = A
spacetype(::AgentBasedModel{A, S}) where {A, S} = S

"""
    AgentBasedModel(AgentType [, space]; scheduler, properties, warn)
Create an agent based model from the given agent type
and the `space`.
You can provide an agent _instance_ instead of type, and the type will be
deduced. `ABM` is equivalent with `AgentBasedModel`.
The agents are stored in a dictionary `model.agents`, where the keys are the
agent IDs, while the values are the agents themselves.
It is recommended however to use [`id2agent`](@ref) to get an agent.

`space` can be omitted, which means that all agents are virtually in one node
and have no spatial structure.
If space is omitted, some functions that facilitate agent-space interactions will not work.

Optionally provide a `scheduler` that decides the order with which agents
are activated in the model, and `properties`
for additional model-level properties.
This is accessed as `model.properties` for later use.

Type tests for `AgentType` are done, use `warn=false` to silence them.
"""
function AgentBasedModel(
        ::Type{A}, space::S = nothing;
        scheduler::F = fastest, properties::P = nothing, warn = true
        ) where {A<:AbstractAgent, S<:SpaceType, F, P}
    agent_validator(A, space, warn)

    agents = Dict{Int, A}()
    return ABM{A, S, F, P}(agents, space, scheduler, properties)
end
const ABM = AgentBasedModel

function AgentBasedModel(
        agent::A, space::S = nothing;
        scheduler::F = fastest, properties::P = nothing, warn = true
        ) where {A<:AbstractAgent, S<:SpaceType, F, P}
    agent_validator(typeof(agent), space, warn)

    agents = Dict{Int, A}()
    return ABM{A, S, F, P}(agents, space, scheduler, properties)
end

function Base.show(io::IO, abm::ABM{A}) where {A}
    s = "AgentBasedModel with $(nagents(abm)) agents of type $(nameof(A))"
    if abm.space == nothing
        s*= "\n no space"
    else
        s*= "\n space: $(sprint(show, abm.space))"
    end
    s*= "\n scheduler: $(nameof(abm.scheduler))"
    print(io, s)
    if abm.properties ≠ nothing
        print(io, "\n properties: ", abm.properties)
    end
end

"""
    agent_validator(agent, space)
Validate the user supplied agent (subtype of `AbstractAgent`).
Checks for mutability and existence and correct types for fields depending on `SpaceType`.
"""
function agent_validator(::Type{A}, space::S, warn::Bool) where {A<:AbstractAgent, S<:SpaceType}
    # Check A for required properties & fields
    if warn
        isconcretetype(A) || @warn "Agent struct should be a concrete type. If your agent is parametrically typed, you're probably seeing this warning because you gave `Agent` instead of `Agent{Float64}` (for example) to this function. You can also create an instance of your agent and pass it to this function. If you want to use `Union` types, you can silence this warning."
        isbitstype(A) && @warn "Agent struct should be mutable. Try adding the `mutable` keyword infront of `struct` in your agent definition."
    end
    (any(isequal(:id), fieldnames(A)) && fieldnames(A)[1] == :id) || throw(ArgumentError("First field of Agent struct must be `id` (it should be of type `Int`)."))
    fieldtype(A, :id) <: Integer || throw(ArgumentError("`id` field in Agent struct must be of type `Int`."))
    if space != nothing
        (any(isequal(:pos), fieldnames(A)) && fieldnames(A)[2] == :pos) || throw(ArgumentError("Second field of Agent struct must be `pos` when using a space."))
        # Check `pos` field in A has the correct type
        pos_type = fieldtype(A, :pos)
        space_type = typeof(space)
        if space_type <: GraphSpace && !(pos_type <: Integer)
            throw(ArgumentError("`pos` field in Agent struct must be of type `Int` when using GraphSpace."))
        elseif space_type <: GridSpace && !(pos_type <: NTuple{D, Integer} where {D})
            throw(ArgumentError("`pos` field in Agent struct must be of type `NTuple{Int}` when using GridSpace."))
        elseif space_type <: ContinuousSpace
            if !(pos_type <: NTuple{D, <:AbstractFloat} where {D})
                throw(ArgumentError("`pos` field in Agent struct must be of type `NTuple{<:AbstractFloat}` when using ContinuousSpace."))
            end
            if warn && any(isequal(:vel), fieldnames(A)) && !(fieldtype(A, :vel) <: NTuple{D, <:AbstractFloat} where {D})
                @warn "`vel` field in Agent struct should be of type `NTuple{<:AbstractFloat}` when using ContinuousSpace."
            end
        end
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

"""
    allagents(model)
Return an iterator over all agents of the model.
"""
allagents(model) = values(model.agents)

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

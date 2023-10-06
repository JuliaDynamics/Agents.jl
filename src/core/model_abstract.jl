# This file defines the ABM interface for Agents.jl and hence
# also instructs how to add more/new types of ABM implementations.
# All methods, whose defaults won't apply, must be extended
# during the definition of a new ABM type.
export AgentBasedModel, ABM
export abmrng, abmscheduler, abmspace, abmproperties, agent_container
export random_agent, random_id, nagents, allagents, allids, seed!

###########################################################################################
# %% Fundamental type definitions
###########################################################################################
"""
    AbstractSpace

Supertype of all concrete space implementations for Agents.jl.
"""
abstract type AbstractSpace end
abstract type DiscreteSpace <: AbstractSpace end
SpaceType = Union{Nothing,AbstractSpace}

# This is a collection of valid position types, sometimes used for ambiguity resolution
ValidPos = Union{
    Int, # graph
    NTuple{N,Int}, # grid
    NTuple{M,<:AbstractFloat}, # continuous
    SVector{M,<:AbstractFloat}, # continuous
    Tuple{Int,Int,Float64} # osm
} where {N,M}


"""
    AgentBasedModel

An `AgentBasedModel` is the abstract supertype encompassing models in Agents.jl.
All models are some concrete implementation of `AgentBasedModel` and follow its
interface (see below). `ABM` is an alias to `AgentBasedModel`.

For backwards compatibility, the following function is valid:
```julia
AgentBasedModel(AgentType [, space]; properties, kwargs...) → model
```
which dispatches to [`StandardABM`](@ref).

## Available concrete implementations

- [`StandardABM`](@ref)
- [`Unremovable`](@ref)

## Interface of `AgentBasedModel`

- `model[id]` returns the agent with given `id`.
- `abmproperties(model)` returns the `properties` container storing model-level properties.
- `model.property`:  If the model `properties` is a dictionary with
  key type `Symbol`, or if it is a composite type (`struct`), then the syntax
  `model.property` will return the model property with key `:property`.
- `abmrng(model)` will return the random number generator of the model.
  It is strongly recommended to give `abmrng(model)` to all calls to `rand` and similar
  functions, so that reproducibility can be established in your modelling workflow.
- `allids(model)/allagents(model)` returns an iterator over all IDs/agents in the model.

This interface, along with the internal interface described in the Developer's Docs,
allows instances of `AgentBasedModel` to be used with any of the [API](@ref) functions
such as `move_agent!`, etc.

Many more functions exist in the API page, such as [`allagents`](@ref).
"""
abstract type AgentBasedModel{S<:SpaceType, A<:AbstractAgent} end
const ABM = AgentBasedModel

# To see the internal interface for `AgentBasedModel`, see below the
# internal methods or the dev docs.

function notimplemented(model)
    error("Function not implemented for model of type $(nameof(typeof(model))) "*
    "with space type $(nameof(typeof(abmspace(model))))")
end

###########################################################################################
# %% Mandatory methods - public
###########################################################################################
"""
    model[id]
    getindex(model::ABM, id::Int)

Return an agent given its ID.
"""
Base.getindex(m::ABM, id::Int) = agent_container(m)[id]

"""
    abmrng(model::ABM)
Return the random number generator stored in the `model`.
"""
abmrng(model::ABM) = getfield(model, :rng)

"""
    abmproperties(model::ABM)
Return the properties container stored in the `model`.
"""
abmproperties(model::ABM) = getfield(model, :properties)

"""
    abmscheduler(model)
Return the default scheduler stored in `model`.
"""
abmscheduler(model::ABM) = getfield(model, :scheduler)

"""
    abmspace(model::ABM)
Return the space instance stored in the `model`.
"""
abmspace(model::ABM) = getfield(model, :space)

"""
    allids(model)
Return an iterator over all agent IDs of the model.
"""
allids(model) = eachindex(agent_container(model))

"""
    allagents(model)
Return an iterator over all agents of the model.
"""
allagents(model) = values(agent_container(model))

"""
    nagents(model::ABM)
Return the number of agents in the `model`.
"""
nagents(model::ABM) = length(allids(model))

"""
    nextid(model::ABM) → id
Return a valid `id` for creating a new agent with it.
"""
nextid(model::ABM) = notimplemented(model)

"""
    random_id(model) → id
Return a random id from the model.
"""
random_id(model) = rand(abmrng(model), allids(model))

"""
    random_agent(model) → agent
Return a random agent from the model.
"""
random_agent(model) = model[random_id(model)]

"""
    random_agent(model, condition; optimistic=true, alloc = false) → agent
Return a random agent from the model that satisfies `condition(agent) == true`.
The function generates a random permutation of agent IDs and iterates through
them. If no agent satisfies the condition, `nothing` is returned instead.

## Keywords
`optimistic = true` changes the algorithm used to be non-allocating but
potentially more variable in performance. This should be faster if the condition
is `true` for a large proportion of the population (for example if the agents
are split into groups).

`alloc` can be used to employ a different fallback strategy in case the
optimistic version doesn't find any agent satisfying the condition: if the filtering
condition is expensive an allocating fallback can be more performant.
"""
function random_agent(model, condition; optimistic = true, alloc = false)
    if optimistic
        return optimistic_random_agent(model, condition, alloc)
    else
        return fallback_random_agent(model, condition, alloc)
    end
end

function optimistic_random_agent(model, condition, alloc; n_attempts = nagents(model))
    @inbounds while n_attempts != 0
        idx = random_id(model)
        condition(model[idx]) && return model[idx]
        n_attempts -= 1
    end
    return fallback_random_agent(model, condition, alloc)
end

function fallback_random_agent(model, condition, alloc)
    if alloc
        iter_ids = allids(model)
        return sampling_with_condition_agents_single(iter_ids, condition, model)
    else
        iter_agents = allagents(model)
        iter_filtered = Iterators.filter(agent -> condition(agent), iter_agents)
        return resorvoir_sampling_single(iter_filtered, model)
    end
end

"""
    model.prop
    getproperty(model::ABM, :prop)

Return a property with name `:prop` from the current `model`, assuming the model `properties`
are either a dictionary with key type `Symbol` or a Julia struct.
For example, if a model has the set of properties `Dict(:weight => 5, :current => false)`,
retrieving these values can be obtained via `model.weight`.
"""
function Base.getproperty(m::ABM, s::Symbol)
    p = abmproperties(m)
    if p isa Dict
        return getindex(p, s)
    else # properties is assumed to be a struct
        return getproperty(p, s)
    end
end

function Base.setproperty!(m::ABM, s::Symbol, x)
    properties = abmproperties(m)
    exception = ErrorException(
        "Cannot set property $(s) for model $(nameof(typeof(m))) with "*
        "properties container type $(typeof(properties))."
    )
    properties === nothing && throw(exception)
    if properties isa Dict && haskey(properties, s)
        properties[s] = x
    elseif hasproperty(properties, s)
        setproperty!(properties, s, x)
    else
        throw(exception)
    end
end

###########################################################################################
# %% Mandatory methods - internal
###########################################################################################

###########################################################################################
# %% Non-public methods. Must be implemented but are not exported
###########################################################################################
agent_container(model::ABM) = getfield(model, :agents)
agent_step_field(model::ABM) = getfield(model, :agent_step)
model_step_field(model::ABM) = getfield(model, :model_step)

agenttype(::ABM{S,A}) where {S,A} = A
spacetype(::ABM{S}) where {S} = S

"""
    add_agent_to_model!(agent, model)
Add the agent to the model's internal container, if the addition is valid
given the agent's ID and those already in the model. Otherwise error.
"""
add_agent_to_model!(agent, model) = notimplemented(model)

"""
    remove_agent_from_model!(agent, model)
Remove the agent from the model's internal container.
"""
remove_agent_from_model!(agent, model) = notimplemented(model)

function Base.setindex!(m::ABM, args...; kwargs...)
    error("`setindex!` or `model[id] = agent` are invalid. Use `add_agent!` instead.")
end

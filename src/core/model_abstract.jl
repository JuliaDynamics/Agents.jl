# This file defines the ABM interface for Agents.jl and hence
# also instructs how to add more/new types of ABM implementations.
# All methods, whose defaults won't apply, must be extended
# during the definition of a new ABM type.
export AgentBasedModel, ABM
export abmrng, abmscheduler, abmspace, abmtime, abmproperties, hasid

###########################################################################################
# %% Fundamental type definitions
###########################################################################################
"""
    AbstractSpace

Supertype of all concrete space implementations for Agents.jl.
"""
abstract type AbstractSpace end
abstract type DiscreteSpace <: AbstractSpace end
SpaceType = Union{Nothing, AbstractSpace}

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

`AgentBasedModel` is the abstract supertype encompassing models in Agents.jl.
All models are some concrete implementation of `AgentBasedModel` and follow its
interface (see below). `ABM` is an alias to `AgentBasedModel`.

## Available concrete implementations

- [`StandardABM`](@ref)
- [`EventQueueABM`](@ref)

It is also straightforward to create your own versions of `AgentBasedModel`,
see [the corresponding entry in the developer documentation](@ref make_new_model).

## Interface of `AgentBasedModel`

- `model[id]` returns the agent with given `id`.
- `abmproperties(model)` returns the `properties` container storing model-level properties.
- `model.property`:  If the model `properties` is a dictionary with
  key type `Symbol`, or if it is a composite type (`struct`), then the syntax
  `model.property` will return the model property with key `:property`.
- `abmtime(model)` will return the current time of the model. All models start from time 0
  and time is incremented as the model is [`step!`](@ref)-ped.
- `abmrng(model)` will return the random number generator of the model.
  It is strongly recommended to give `abmrng(model)` to all calls to `rand` and similar
  functions, so that reproducibility can be established in your modelling workflow.
- `allids(model)/allagents(model)` returns an iterator over all IDs/agents in the model.
- `hasid(model, id)` returns `true` if the model has an agent with given `id`.

`AgentBasedModel` defines an extendable interface composed of the above syntax as well
as a few more additional functions described in the Developer's Docs.
Following this interface you can implement new variants of an `AgentBasedModel`.
The interface allows instances of `AgentBasedModel` to be used with any of the [API](@ref).
For example, functions such as [`random_agent`](@ref), [`move_agent!`](@ref) or
[`add_agent`](@ref) do not need to be implemented manually but work out of the box
provided the `AgentBasedModel` interface is followed.
"""
abstract type AgentBasedModel{S<:SpaceType} end
const ABM = AgentBasedModel

# To see the internal interface for `AgentBasedModel`, see below the
# internal methods or the dev docs.

notimplemented(::A) where {A<:ABM{S}} where {S} =
    error(lazy"Function not implemented for model of type $(nameof(A)) with space type $S.")

###########################################################################################
# %% Mandatory methods - public
###########################################################################################
# Here we make the default decision that all important components
# of an ABM will be direct fields of the type. It isn't enforced
# but it is likely that it will always be the case

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
    abmscheduler(model::ABM)

Return the default scheduler stored in `model`.
"""
abmscheduler(model::ABM) = getfield(model, :scheduler)

"""
    abmspace(model::ABM)
Return the space instance stored in the `model`.
"""
abmspace(model::ABM) = getfield(model, :space)

"""
    abmtime(model::ABM)
Return the current time of the `model`.
All models are initialized at time 0.
"""
abmtime(model::ABM) = getfield(model, :time)[]

"""
    model.prop
    getproperty(model::ABM, :prop)

Return a property with name `:prop` from the current `model`, assuming the model `properties`
are either a dictionary with key type `Symbol` or a Julia struct.
For example, if a model has the set of properties `Dict(:weight => 5, :current => false)`,
retrieving these values can be obtained via `model.weight` or `model.current`.
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

"""
    hasid(model, id::Int) → true/false
    hasid(model, agent::AbstractAgent) → true/false

Return `true` if the `model` has an agent with given `id` or has the given `agent`.
"""
hasid(model, id::Int) = haskey(agent_container(model), id)
# vector version is extended in the model_accessing_API.jl
hasid(model, a::AbstractAgent) = hasid(model, a.id)

###########################################################################################
# %% Mandatory methods - internal
###########################################################################################
# The first type parameter of any `ABM` subtype must be the space type.
spacetype(::ABM{S}) where {S} = S

tuple_agenttype(model::ABM) = getfield(model, :agents_types)

"""
    agent_container(model::ABM)

Return the "container" of agents in the model.
"""
agent_container(model::ABM) = getfield(model, :agents)

"""
    nextid(model::ABM) → id

Return a valid `id` for creating a new agent with it.
"""
nextid(model::ABM) = notimplemented(model)

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

"""
    discretimeabm(model)

Return `true` if the model is in discrete time, `false` if it is continuous.
"""
discretimeabm(model::ABM) = notimplemented(model)

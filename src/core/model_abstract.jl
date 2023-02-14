# This file defines the ABM interface for Agents.jl and hence
# also instructs how to add more/new types of ABM implementations.
# All methods, whose defaults won't apply, must be extended
# during the definition of a new ABM type.
export AbstractAgentBasedModel, ABM
export abmrng
export random_agent, nagents, allagents, allids, nextid, seed!

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
    Tuple{Int,Int,Float64} # osm
} where {N,M}


"""
    AbstractAgentBasedModel{S,A}
Supertype of all concrete ABM implementations for Agents.jl. Defines the ABM interface.
It is typed with type `S` for space and `A` for agent(s).
"""
abstract type AbstractAgentBasedModel{S<:SpaceType,A<:AbstractAgent} end
const AABM = AbstractAgentBasedModel
# In the future `AgentBasedModel` will be come an abstract type,
# and the current `AgentBasedModel` will be renamed to something like `VanillaABM`.
const ABM = AbstractAgentBasedModel

function notimplemented(model)
    error("Function not implemented for model of type $(nameof(typeof(model))) "*
    "with space type $(nameof(typeof(space(model))))")
end

###########################################################################################
# %% Public methods. Must be implemented and are exported.
###########################################################################################
"""
    model[id]
    getindex(model::ABM, id::Integer)

Return an agent given its ID.
"""
Base.getindex(m::ABM, id::Integer) = agent_container(m)[id]

"""
    abmrng(model::ABM)
Return the random number generator stored in the `model`.
"""
abmrng(model::ABM) = getfield(model, :rng)

"""
    abmscheduler(model)
Return the default scheduler stored in `model`.
"""
abmscheduler(model::ABM) = getfield(model, :scheduler)

"""
    schedule(model) → ids
Return an iterator over the scheduled IDs using the model's scheduler.
Literally equivalent with `cheduler(model)(model)`.
"""
schedule(model::ABM) = abmscheduler(model)(model)

"""
    nextid(model::ABM) → id
Return a valid `id` for creating a new agent with it.
"""
nextid(model::ABM) = length(allids(model)) + 1

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
    random_agent(model) → agent
Return a random agent from the model.
"""
random_agent(model) = model[rand(abmrng(model), allids(model))]


"""
    random_agent(model, condition) → agent
Return a random agent from the model that satisfies `condition(agent) == true`.
The function generates a random permutation of agent IDs and iterates through them.
If no agent satisfies the condition, `nothing` is returned instead.
"""
function random_agent(model, condition)
    ids = shuffle!(abmrng(model), collect(allids(model)))
    i, L = 1, length(ids)
    a = model[ids[1]]
    while !condition(a)
        i += 1
        i > L && return nothing
        a = model[ids[i]]
    end
    return a
end



# TODO: In the future, it is INVALID to access space, agents, etc., with the .field syntax.
# Instead, use the API functions such as `abmrng, abmspace`, etc.
# We just need to re-write the codebase to not use .field access.
"""
    model.prop
    getproperty(model::ABM, :prop)

Return a property with name `:prop` from the current `model`, assuming the model `properties`
are either a dictionary with key type `Symbol` or a Julia struct.
For example, if a model has the set of properties `Dict(:weight => 5, :current => false)`,
retrieving these values can be obtained via `model.weight`.

The property names `:agents, :space, :scheduler, :properties, :maxid` are internals
and **should not be accessed by the user**.
"""
function Base.getproperty(m::ABM, s::Symbol)
    if s === :agents
        return getfield(m, :agents)
    elseif s === :space
        return getfield(m, :space)
    elseif s === :scheduler
        return getfield(m, :scheduler)
    elseif s === :properties
        return getfield(m, :properties)
    elseif s === :rng
        return getfield(m, :rng)
    elseif s === :maxid
        return getfield(m, :maxid)
    elseif P <: Dict
        return getindex(getfield(m, :properties), s)
    else # properties is assumed to be a struct
        return getproperty(getfield(m, :properties), s)
    end
end

function Base.setproperty!(m::ABM, s::Symbol, x)
    exception = ErrorException("Cannot set $(s) in this manner. Please use the `AgentBasedModel` constructor.")
    properties = getfield(m, :properties)
    properties === nothing && throw(exception)
    if P <: Dict && haskey(properties, s)
        properties[s] = x
    elseif hasproperty(properties, s)
        setproperty!(properties, s, x)
    else
        throw(exception)
    end
end


###########################################################################################
# %% Non-public methods. Must be implemented but are not exported
###########################################################################################
agent_container(model::ABM) = getfield(model, :agents)
agenttype(::ABM{S,A}) where {S,A} = A
spacetype(::ABM{S}) where {S} = S

"""
    add_agent_to_model!(agent, model)
Add the agent to the model's internal container.
"""
add_agent_to_model!(agent, model) = notimplemented(model)

"""
    remove_agent_from_model!(agent, model)
Remove the agent from the model. This function is called before the agent is
inserted into the model dictionary and `maxid` has been updated. This function
is NOT part of the public API.
"""
remove_agent_from_model!(agent, model) = notimplemented(model)

"""
    abmspace(model::ABM)
Return the space instance stored in the `model`.
"""
abmspace(model::ABM) = model.space

function Base.setindex!(m::ABM, args...; kwargs...)
    error("`setindex!` or `model[id] = agent` are invalid. Use `add_agent!(model, agent)` "*
    "or other variants of an `add_agent_...` function to add agents to an ABM.")
end
# This file defines the ABM interface for Agents.jl and hence
# also instructs how to add more/new types of ABM implementations.
# All methods, whose defaults won't apply, must be extended
# during the definition of a new ABM type.
export AbstractAgentBasedModel, ABM

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
# %% Public methods. Must be implemented and are exported. A sensible default is given.
###########################################################################################
"""
    model[id]
    getindex(model::ABM, id::Integer)

Return an agent given its ID.
"""
Base.getindex(m::ABM, id::Integer) = agent_container(m)[id]

###########################################################################################
# %% Non-public methods. Must be implemented but are not exported. No defaults.
###########################################################################################
agent_container(model::ABM) = model.agents
agenttype(::ABM{S,A}) where {S,A} = A
spacetype(::ABM{S}) where {S} = S

"""
    add_agent_to_model!(agent, model)
Add the agent to the model. This function is called before the agent is inserted
into the model dictionary and `maxid` has been updated. This function is NOT
part of the public API.
"""
add_agent_to_model!(agent, model) = notimplemented(model)

"""
    remove_agent_from_model!(agent, model)
Remove the agent from the model. This function is called before the agent is
inserted into the model dictionary and `maxid` has been updated. This function
is NOT part of the public API.
"""
remove_agent_from_model!(agent, model) = notimplemented(model)
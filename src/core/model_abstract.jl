# This file defines the ABM interface for Agents.jl and hence
# also instructs how to add more/new types of ABM implementations.
# All methods, whose defaults won't apply, must be extended
# during the definition of a new ABM type.
export AbstractAgentBasedModel

###########################################################################################
# %% Fundamental type definitions
###########################################################################################
"""
    AbstractAgentBasedModel
Supertype of all concrete ABM implementations for Agents.jl. Defines the ABM interface.
"""
abstract type AbstractAgentBasedModel end
const AABM = AbstractAgentBasedModel
const ABM = AbstractAgentBasedModel

"""
    AbstractAgentBasedModel
Supertype of all concrete space implementations for Agents.jl.
"""
abstract type AbstractSpace end

SpaceType = Union{Nothing,AbstractSpace}

abstract type DiscreteSpace <: AbstractSpace end

# This is a collection of valid position types, sometimes used for ambiguity resolution
ValidPos = Union{
    Int, # graph
    NTuple{N,Int}, # grid
    NTuple{M,<:AbstractFloat}, # continuous
    Tuple{Int,Int,Float64} # osm
} where {N,M}


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
"""
    agent_container(model::ABM)

Return a container that stores the agents in the model.
"""
agent_container(model::ABM) =

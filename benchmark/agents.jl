mutable struct GraphAgent <: AbstractAgent
    id::Int
    pos::Int
    one::Float64
    two::Bool
end

mutable struct GraphAgentTwo <: AbstractAgent
    id::Int
    pos::Int
end

mutable struct GraphAgentThree <: AbstractAgent
    id::Int
    pos::Int
end

mutable struct GraphAgentFour <: AbstractAgent
    id::Int
    pos::Int
end

mutable struct GraphAgentFive <: AbstractAgent
    id::Int
    pos::Int
end

mutable struct GridAgent <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    one::Float64
    two::Bool
end

mutable struct GridAgentTwo <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
end

mutable struct GridAgentThree <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
end

mutable struct GridAgentFour <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
end

mutable struct GridAgentFive <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
end

mutable struct ContinuousAgent <: AbstractAgent
    id::Int
    pos::NTuple{3,Float64}
    vel::NTuple{3,Float64}
    one::Float64
    two::Bool
end

mutable struct ContinuousAgentTwo <: AbstractAgent
    id::Int
    pos::NTuple{3,Float64}
    vel::NTuple{3,Float64}
end

mutable struct ContinuousAgentThree <: AbstractAgent
    id::Int
    pos::NTuple{3,Float64}
    vel::NTuple{3,Float64}
end

mutable struct ContinuousAgentFour <: AbstractAgent
    id::Int
    pos::NTuple{3,Float64}
    vel::NTuple{3,Float64}
end

mutable struct ContinuousAgentFive <: AbstractAgent
    id::Int
    pos::NTuple{3,Float64}
    vel::NTuple{3,Float64}
end


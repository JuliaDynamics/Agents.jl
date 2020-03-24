using Test, Agents, Random, LightGraphs, SQLite, DataFrames

mutable struct Agent0 <: AbstractAgent
  id::Int
end

mutable struct Agent1 <: AbstractAgent
  id::Int
  pos::Tuple{Int,Int}
end

mutable struct Agent2 <: AbstractAgent
  id::Int
  weight::Float64
end

mutable struct Agent3 <: AbstractAgent
  id::Int
  pos::Tuple{Int,Int}
  weight::Float64
end

mutable struct Agent4 <: AbstractAgent
  id::Int
  pos::Tuple{Int,Int}
  p::Int
end

mutable struct Agent5 <: AbstractAgent
  id::Int
  pos::Int
  weight::Float64
end

mutable struct Agent6 <: AbstractAgent
  id::Int
  pos::NTuple{2, Float64}
  vel::NTuple{2, Float64}
  diameter::Float64
end

@testset "all tests" begin

include("api_tests.jl")
include("space_test.jl")
include("interaction_tests.jl")
include("data_collector_test.jl")
include("CA_test.jl")
include("continuousSpace_tests.jl")

end

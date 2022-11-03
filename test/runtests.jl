using Test, Agents, Random
using Agents.Graphs, Agents.DataFrames
using StatsBase: mean
using StableRNGs

using Distributed
addprocs(2)
@everywhere begin
    using Test, Agents, Random
    using Agents.Graphs, Agents.DataFrames
    using StatsBase: mean
    using StableRNGs
end

mutable struct Agent0 <: AbstractAgent
    id::Int
end

mutable struct Agent1 <: AbstractAgent
    id::Int
    pos::Dims{2}
end

mutable struct Agent2 <: AbstractAgent
    id::Int
    weight::Float64
end

mutable struct Agent3 <: AbstractAgent
    id::Int
    pos::Dims{2}
    weight::Float64
end

mutable struct Agent4 <: AbstractAgent
    id::Int
    pos::Dims{2}
    p::Int
end

mutable struct Agent5 <: AbstractAgent
    id::Int
    pos::Int
    weight::Float64
end

mutable struct Agent6 <: AbstractAgent
    id::Int
    pos::NTuple{2,Float64}
    vel::NTuple{2,Float64}
    weight::Float64
end

mutable struct Agent7 <: AbstractAgent
    id::Int
    pos::Int
    f1::Bool
    f2::Int
end

Agent7(id, pos; f1, f2) = Agent7(id, pos, f1, f2)

mutable struct Agent8 <: AbstractAgent
    id::Int
    pos::NTuple{2,Float64}
    f1::Bool
    f2::Int
end

Agent8(id, pos; f1, f2) = Agent8(id, pos, f1, f2)

@testset "Agents.jl Tests" begin
    include("model_creation_tests.jl")
    include("api_tests.jl")
    include("randomness_tests.jl")
    include("scheduler_tests.jl")
    include("model_access.jl")
    include("space_test.jl")
    include("grid_space_tests.jl")
    include("collect_tests.jl")
    include("continuous_space_tests.jl")
    include("osm_tests.jl")
    include("astar_tests.jl")
    include("graph_tests.jl")
    include("csv_tests.jl")
    include("jld2_tests.jl")
end

using BenchmarkTools, Agents, LightGraphs

const SUITE = BenchmarkGroup(["Agents"])

mutable struct DiscreteAgent <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
end

mutable struct ContinuousAgent <: AbstractAgent
    id::Int
    pos::NTuple{2,Float64}
    vel::NTuple{2,Float64}
end

SUITE["space"] = BenchmarkGroup(["graph", "grid", "continuous"])
SUITE["space"]["graph"] = @benchmarkable GraphSpace(complete_digraph(1000))
SUITE["space"]["grid"] = @benchmarkable GridSpace((500, 500))
SUITE["space"]["continuous"] = @benchmarkable ContinuousSpace(5; extend = (100, 100, 100, 100, 100))

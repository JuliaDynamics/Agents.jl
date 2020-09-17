using BenchmarkTools, Agents, LightGraphs

const SUITE = BenchmarkGroup(["Agents"])

mutable struct DiscreteAgent <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
end

mutable struct DiscreteAgentTwo <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
end

mutable struct ContinuousAgent <: AbstractAgent
    id::Int
    pos::NTuple{2,Float64}
    vel::NTuple{2,Float64}
end

mutable struct ContinuousAgentTwo <: AbstractAgent
    id::Int
    pos::NTuple{2,Float64}
    vel::NTuple{2,Float64}
end

grid_model = ABM(DiscreteAgent, GridSpace((10, 10)))
grid_union_model = ABM(DiscreteAgent, GridSpace((10, 10)))

SUITE["space"] = BenchmarkGroup(["graph", "grid", "continuous"])
SUITE["space"]["graph"] = @benchmarkable GraphSpace(complete_digraph(1000))
SUITE["space"]["grid"] = @benchmarkable GridSpace((500, 500))
SUITE["space"]["continuous"] = @benchmarkable ContinuousSpace(5; extend = (100, 100, 100, 100, 100))

SUITE["model"]["initialise"]["graph"] = @benchmarkable ABM(DiscreteAgent, GraphSpace(complete_digraph(5)))
SUITE["model"]["initialise"]["grid"] = @benchmarkable ABM(DiscreteAgent, GridSpace((10, 10)))
SUITE["model"]["initialise"]["continuous"] = @benchmarkable ABM(ContinuousAgent, ContinuousSpace(3))
SUITE["model"]["initialise_union"]["graph"] = @benchmarkable ABM(Union{DiscreteAgent, DiscreteAgentTwo}, GraphSpace(complete_digraph(5)))
SUITE["model"]["initialise_union"]["grid"] = @benchmarkable ABM(Union{DiscreteAgent, DiscreteAgentTwo}, GridSpace((10, 10)))
SUITE["model"]["initialise_union"]["continuous"] = @benchmarkable ABM(Union{ContinuousAgent, ContinuousAgentTwo}, ContinuousSpace(3))

SUITE["grid"]["add"]["agent"] = @benchmarkable add_agent!(DiscreteAgent(1, (2,3)), $grid_model)
SUITE["grid"]["add"]["agent_pos"] = @benchmarkable add_agent_pos!(DiscreteAgent(1, (2,3)), $grid_model)
SUITE["grid"]["add"]["agent_single"] = @benchmarkable add_agent_single!(DiscreteAgent(1, (2,3)), $grid_model)
# Ready for current master
#SUITE["grid"]["add"]["agent_union"] = @benchmarkable add_agent!(DiscreteAgent, $grid_union_model)
SUITE["grid"]["add"]["create"] = @benchmarkable add_agent!($grid_model)
SUITE["grid"]["add"]["create_pos"] = @benchmarkable add_agent!((1,3), $grid_model)
SUITE["grid"]["add"]["create_single"] = @benchmarkable add_agent_single!($grid_model)

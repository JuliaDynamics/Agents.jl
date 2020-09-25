using BenchmarkTools, Agents, LightGraphs

const SUITE = BenchmarkGroup(["Agents"])

include("agents.jl")

#### MODEL CREATION ####

graph_space = GraphSpace(complete_digraph(5))
grid_space = GridSpace((10, 10))
continuous_space = ContinuousSpace(3)
graph_space_two = GraphSpace(complete_digraph(5))
grid_space_two = GridSpace((10, 10))
continuous_space_two = ContinuousSpace(3)

SUITE["model"] = BenchmarkGroup(["initialise", "initialise_union"])
for set in SUITE["model"].tags
    SUITE["model"][set] = BenchmarkGroup(["graph", "grid", "continuous"])
end
SUITE["model"]["initialise"]["graph"] = @benchmarkable ABM(GraphAgent, $graph_space)
SUITE["model"]["initialise"]["grid"] = @benchmarkable ABM(GridAgent, $grid_space)
SUITE["model"]["initialise"]["continuous"] =
    @benchmarkable ABM(ContinuousAgent, $continuous_space)
SUITE["model"]["initialise_union"]["graph"] = @benchmarkable ABM(
    Union{GraphAgent,GraphAgentTwo,GraphAgentThree,GraphAgentFour,GraphAgentFive},
    $graph_space_two;
    warn = false,
)
SUITE["model"]["initialise_union"]["grid"] = @benchmarkable ABM(
    Union{GridAgent,GridAgentTwo,GridAgentTwo,GridAgentThree,GridAgentFour,GridAgentFive},
    $grid_space_two;
    warn = false,
)
SUITE["model"]["initialise_union"]["continuous"] = @benchmarkable ABM(
    Union{
        ContinuousAgent,
        ContinuousAgentTwo,
        ContinuousAgentThree,
        ContinuousAgentFour,
        ContinuousAgentFive,
    },
    $continuous_space_two;
    warn = false,
)


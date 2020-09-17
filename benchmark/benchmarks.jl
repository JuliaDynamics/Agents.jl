using BenchmarkTools, Agents, LightGraphs

const SUITE = BenchmarkGroup(["Agents"])

include("agents.jl")

grid_model = ABM(GridAgent, GridSpace((1000, 1000)))
grid_agent = GridAgent(1, (2,3))
grid_union_model = ABM(Union{GridAgent, GridAgentTwo, GridAgentThree, GridAgentFour, GridAgentFive}, GridSpace((1000, 1000)); warn=false)

SUITE["space"] = BenchmarkGroup(["graph", "grid", "continuous"])
SUITE["space"]["graph"] = @benchmarkable GraphSpace(complete_digraph(1000))
SUITE["space"]["grid"] = @benchmarkable GridSpace((500, 500))
SUITE["space"]["continuous"] = @benchmarkable ContinuousSpace(5; extend = (100, 100, 100, 100, 100))

SUITE["model"] = BenchmarkGroup(["initialise", "initialise_union"])
SUITE["model"]["initialise"] = BenchmarkGroup(["graph", "grid", "continuous"])
SUITE["model"]["initialise"]["graph"] = @benchmarkable ABM(GraphAgent, GraphSpace(complete_digraph(5)))
SUITE["model"]["initialise"]["grid"] = @benchmarkable ABM(GridAgent, GridSpace((10, 10)))
SUITE["model"]["initialise"]["continuous"] = @benchmarkable ABM(ContinuousAgent, ContinuousSpace(3))
SUITE["model"]["initialise_union"] = BenchmarkGroup(["graph", "grid", "continuous"])
SUITE["model"]["initialise_union"]["graph"] = @benchmarkable ABM(Union{GraphAgent, GraphAgentTwo}, GraphSpace(complete_digraph(5)); warn=false)
SUITE["model"]["initialise_union"]["grid"] = @benchmarkable ABM(Union{GridAgent, GridAgentTwo}, GridSpace((10, 10)); warn=false)
SUITE["model"]["initialise_union"]["continuous"] = @benchmarkable ABM(Union{ContinuousAgent, ContinuousAgentTwo}, ContinuousSpace(3); warn=false)

SUITE["grid"] = BenchmarkGroup(["add","add_union"])
SUITE["grid"]["add"] = BenchmarkGroup(["agent", "agent_pos", "agent_single", "create", "create_pos", "create_single"])
SUITE["grid"]["add"]["agent"] = @benchmarkable add_agent!(grid_agent, $grid_model)
# We genocide everything between benchmarks to ensure agents are 'added' and not overwritten
# (also, the add_agent_single! calls need an empty model)
genocide!(grid_model)
SUITE["grid"]["add"]["agent_pos"] = @benchmarkable add_agent_pos!(grid_agent, $grid_model)
genocide!(grid_model)
SUITE["grid"]["add"]["agent_single"] = @benchmarkable add_agent_single!(grid_agent, $grid_model)
genocide!(grid_model)
SUITE["grid"]["add"]["create"] = @benchmarkable add_agent!($grid_model)
genocide!(grid_model)
SUITE["grid"]["add"]["create_pos"] = @benchmarkable add_agent!((1,3), $grid_model)
genocide!(grid_model)
SUITE["grid"]["add"]["create_single"] = @benchmarkable add_agent_single!($grid_model)
SUITE["grid"]["add_union"] = BenchmarkGroup(["agent", "agent_pos", "agent_single"])
# Think this is only on current master, will need to rebase
#SUITE["grid"]["add"]["agent_union"] = @benchmarkable add_agent!(GridAgent, $grid_union_model)
SUITE["grid"]["add_union"]["agent"] = @benchmarkable add_agent!(grid_agent, $grid_union_model)
genocide!(grid_union_model)
SUITE["grid"]["add_union"]["agent_pos"] = @benchmarkable add_agent_pos!(grid_agent, $grid_union_model)
genocide!(grid_union_model)
SUITE["grid"]["add_union"]["agent_single"] = @benchmarkable add_agent_single!(grid_agent, $grid_union_model)

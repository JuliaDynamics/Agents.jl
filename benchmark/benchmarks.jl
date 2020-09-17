using BenchmarkTools, Agents, LightGraphs

const SUITE = BenchmarkGroup(["Agents"])

include("agents.jl")

#### SPACE CONSTRUCTION ####

SUITE["space"] = BenchmarkGroup(["graph", "grid", "continuous"])
SUITE["space"]["graph"] = @benchmarkable GraphSpace(complete_digraph(1000))
SUITE["space"]["grid"] = @benchmarkable GridSpace((500, 500))
SUITE["space"]["continuous"] =
    @benchmarkable ContinuousSpace(5; extend = (100, 100, 100, 100, 100))

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

#### API ###

for space in ["graph", "grid", "continuous"]
    SUITE[space] = BenchmarkGroup(["add", "add_union", "move"])

    SUITE[space]["add"] = BenchmarkGroup([
        "agent",
        "agent_pos",
        "agent_single",
        "create",
        "create_pos",
        "create_single",
    ])
    SUITE[space]["add_union"] = BenchmarkGroup(["agent", "agent_pos", "agent_single"])
    if space == "continuous"
        SUITE[space]["move"] = BenchmarkGroup(["update", "vel"])
    else
        SUITE[space]["move"] = BenchmarkGroup(["random", "pos", "single"])
    end
end
# some spaces have specific things we'd like to add
push!(SUITE["grid"]["add_union"].tags, "agent_fill")
push!(SUITE["grid"]["add"].tags, "create_fill")
# some spaces need a few things dropped
for add in ["add", "add_union"]
    group = SUITE["continuous"][add].tags
    add == "add" && splice!(group, findfirst(t -> t == "create_single", group))
    splice!(group, findfirst(t -> t == "agent_single", group))
end

#### API -> GRAPH ####

graph_model = ABM(GraphAgent, GraphSpace(complete_digraph(30_000)))
graph_agent = GraphAgent(1, 82)
graph_union_model = ABM(
    Union{GraphAgent,GraphAgentTwo,GraphAgentThree,GraphAgentFour,GraphAgentFive},
    GraphSpace(complete_digraph(30_000)), # Needs to be this large otherwise single! will hit the roof
    warn = false,
)

SUITE["graph"]["add"]["agent"] = @benchmarkable add_agent!($graph_agent, $graph_model)
SUITE["graph"]["add"]["agent_pos"] =
    @benchmarkable add_agent_pos!($graph_agent, $graph_model)
SUITE["graph"]["add"]["agent_single"] =
    @benchmarkable add_agent_single!($graph_agent, $graph_model)
SUITE["graph"]["add"]["create_pos"] = @benchmarkable add_agent!(26, $graph_model)
SUITE["graph"]["add"]["create_single"] = @benchmarkable add_agent_single!($graph_model)
SUITE["graph"]["add"]["create"] = @benchmarkable add_agent!($graph_model)

SUITE["graph"]["add_union"]["agent"] =
    @benchmarkable add_agent!($graph_agent, $graph_union_model)
SUITE["graph"]["add_union"]["agent_pos"] =
    @benchmarkable add_agent_pos!($graph_agent, $graph_union_model)
SUITE["graph"]["add_union"]["agent_single"] =
    @benchmarkable add_agent_single!($graph_agent, $graph_union_model)

for _ in 1:50
    add_agent!(graph_model)
end
a = random_agent(graph_model)
SUITE["graph"]["move"]["random"] = @benchmarkable move_agent!($a, $graph_model)
SUITE["graph"]["move"]["pos"] = @benchmarkable move_agent!($a, 68, $graph_model)
SUITE["graph"]["move"]["single"] = @benchmarkable move_agent_single!($a, $graph_model)

#### API -> GRID ####

grid_model = ABM(GridAgent, GridSpace((1000, 1000)))
grid_agent = GridAgent(1, (2, 3))
grid_union_model = ABM(
    Union{GridAgent,GridAgentTwo,GridAgentThree,GridAgentFour,GridAgentFive},
    GridSpace((1000, 1000));
    warn = false,
)

# For fill_space
small_grid_model = ABM(GridAgent, GridSpace((10, 10)))
small_grid_union_model = ABM(
    Union{GridAgent,GridAgentTwo,GridAgentThree,GridAgentFour,GridAgentFive},
    GridSpace((10, 10));
    warn = false,
)

SUITE["grid"]["add"]["agent"] = @benchmarkable add_agent!($grid_agent, $grid_model)
SUITE["grid"]["add"]["agent_pos"] = @benchmarkable add_agent_pos!($grid_agent, $grid_model)
SUITE["grid"]["add"]["agent_single"] =
    @benchmarkable add_agent_single!($grid_agent, $grid_model)
SUITE["grid"]["add"]["create_pos"] = @benchmarkable add_agent!((1, 3), $grid_model)
SUITE["grid"]["add"]["create_single"] = @benchmarkable add_agent_single!($grid_model)
SUITE["grid"]["add"]["create"] = @benchmarkable add_agent!($grid_model)
SUITE["grid"]["add"]["create_fill"] = @benchmarkable fill_space!($small_grid_model)

# Think this is only on current master, will need to rebase
#SUITE["grid"]["add"]["agent_union"] = @benchmarkable add_agent!(GridAgent, $grid_union_model)
SUITE["grid"]["add_union"]["agent"] =
    @benchmarkable add_agent!($grid_agent, $grid_union_model)
SUITE["grid"]["add_union"]["agent_pos"] =
    @benchmarkable add_agent_pos!($grid_agent, $grid_union_model)
SUITE["grid"]["add_union"]["agent_single"] =
    @benchmarkable add_agent_single!($grid_agent, $grid_union_model)
SUITE["grid"]["add_union"]["agent_fill"] =
    @benchmarkable fill_space!(GridAgent, $small_grid_union_model)

for _ in 1:50
    add_agent!(grid_model)
end
a = random_agent(grid_model)
SUITE["grid"]["move"]["random"] = @benchmarkable move_agent!($a, $grid_model)
SUITE["grid"]["move"]["pos"] = @benchmarkable move_agent!($a, (14, 35), $grid_model)
SUITE["grid"]["move"]["single"] = @benchmarkable move_agent_single!($a, $grid_model)

#### API -> CONTINUOUS ####

continuous_agent = ContinuousAgent(1, (2.2, 1.9, 7.5), (0.5, 1.0, 0.01))

# We must create the model inside our benchmark call here, otherwise we hit the issue from #226.

SUITE["continuous"]["add"]["agent"] = @benchmarkable add_agent!(
    $continuous_agent,
    ABM(ContinuousAgent, ContinuousSpace(3; extend = (10.0, 10.0, 10.0))),
)
SUITE["continuous"]["add"]["agent_pos"] = @benchmarkable add_agent_pos!(
    $continuous_agent,
    ABM(ContinuousAgent, ContinuousSpace(3; extend = (10.0, 10.0, 10.0))),
)
SUITE["continuous"]["add"]["create_pos"] = @benchmarkable add_agent!(
    (5.8, 3.5, 9.4),
    ABM(ContinuousAgent, ContinuousSpace(3; extend = (10.0, 10.0, 10.0))),
    (0.9, 0.6, 0.5),
)
SUITE["continuous"]["add"]["create"] = @benchmarkable add_agent!(
    ABM(ContinuousAgent, ContinuousSpace(3; extend = (10.0, 10.0, 10.0))),
    (0.1, 0.7, 0.2),
)

SUITE["continuous"]["add_union"]["agent"] = @benchmarkable add_agent!(
    $continuous_agent,
    ABM(
        Union{
            ContinuousAgent,
            ContinuousAgentTwo,
            ContinuousAgentThree,
            ContinuousAgentFour,
            ContinuousAgentFive,
        },
        ContinuousSpace(3; extend = (10.0, 10.0, 10.0));
        warn = false,
    ),
)
SUITE["continuous"]["add_union"]["agent_pos"] = @benchmarkable add_agent_pos!(
    $continuous_agent,
    ABM(
        Union{
            ContinuousAgent,
            ContinuousAgentTwo,
            ContinuousAgentThree,
            ContinuousAgentFour,
            ContinuousAgentFive,
        },
        ContinuousSpace(3; extend = (10.0, 10.0, 10.0));
        warn = false,
    ),
)

continuous_model = ABM(ContinuousAgent, ContinuousSpace(3; extend = (10.0, 10.0, 10.0)))
for _ in 1:50
    add_agent!(continuous_model, (0.8, 0.7, 1.3))
end
a = random_agent(continuous_model)
SUITE["continuous"]["move"]["update"] = @benchmarkable move_agent!($a, $continuous_model)
SUITE["continuous"]["move"]["vel"] =
    @benchmarkable move_agent!($a, $continuous_model, (1.2, 0.0, 0.7))

#### DATA COLLECTION ###


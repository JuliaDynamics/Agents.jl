using BenchmarkTools, Agents, LightGraphs

const SUITE = BenchmarkGroup(["Agents"])

include("agents.jl")

#### SPACE CONSTRUCTION ####

SUITE["space_creation"] = BenchmarkGroup(["graph", "grid", "continuous"])
SUITE["space_creation"]["graph"] = @benchmarkable GraphSpace(complete_digraph(1000))
SUITE["space_creation"]["grid"] = @benchmarkable GridSpace((500, 500))
SUITE["space_creation"]["continuous"] =
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
    SUITE[space] = BenchmarkGroup(["add", "add_union", "move", "neighbors"])

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
        SUITE[space]["neighbors"] = BenchmarkGroup([
            "space_pos",
            "space_agent",
            "space_pos_iterate",
            "space_agent_iterate",
            "nearest",
            "interacting",
        ])
    else
        SUITE[space]["move"] = BenchmarkGroup(["random", "pos", "single"])
        SUITE[space]["neighbors"] = BenchmarkGroup([
            "space_pos",
            "space_agent",
            "space_pos_iterate",
            "space_agent_iterate",
            "node_pos",
            "node_agent",
        ])
    end
    SUITE[space]["collect"] = BenchmarkGroup(["init_agent", "store_agent"])
end
# some spaces have specific things we'd like to add
push!(SUITE["grid"]["add_union"].tags, "agent_fill")
push!(SUITE["grid"]["add"].tags, "create_fill")
for space in ["grid", "graph"]
    push!(SUITE[space].tags, "node")
    SUITE[space]["node"] = BenchmarkGroup(["contents", "agents"])
end
# some spaces need a few things dropped
for add in ["add", "add_union"]
    group = SUITE["continuous"][add].tags
    add == "add" && splice!(group, findfirst(t -> t == "create_single", group))
    splice!(group, findfirst(t -> t == "agent_single", group))
end

function iterate_over_neighbors(a, model, r)
    s = 0
    for x in space_neighbors(a, model, r)
        s += x
    end
    return s
end

#### API -> GRAPH ####

graph_model = ABM(GraphAgent, GraphSpace(complete_digraph(40_000)))
graph_agent = GraphAgent(1, 82, 6.5, false)
graph_union_model = ABM(
    Union{GraphAgent,GraphAgentTwo,GraphAgentThree,GraphAgentFour,GraphAgentFive},
    GraphSpace(complete_digraph(40_000)), # Needs to be this large otherwise single! will hit the roof
    warn = false,
)

SUITE["graph"]["add"]["agent"] = @benchmarkable add_agent!($graph_agent, $graph_model)
SUITE["graph"]["add"]["agent_pos"] =
    @benchmarkable add_agent_pos!($graph_agent, $graph_model)
SUITE["graph"]["add"]["agent_single"] =
    @benchmarkable add_agent_single!($graph_agent, $graph_model)
SUITE["graph"]["add"]["create_pos"] =
    @benchmarkable add_agent!(26, $graph_model, 6.5, false)
SUITE["graph"]["add"]["create_single"] =
    @benchmarkable add_agent_single!($graph_model, 6.5, false)
SUITE["graph"]["add"]["create"] = @benchmarkable add_agent!($graph_model, 6.5, false)

SUITE["graph"]["add_union"]["agent"] =
    @benchmarkable add_agent!($graph_agent, $graph_union_model)
SUITE["graph"]["add_union"]["agent_pos"] =
    @benchmarkable add_agent_pos!($graph_agent, $graph_union_model)
SUITE["graph"]["add_union"]["agent_single"] =
    @benchmarkable add_agent_single!($graph_agent, $graph_union_model)

graph_model = ABM(GraphAgent, GraphSpace(complete_digraph(100)))
for node in 1:100
    for _ in 1:4
        add_agent!(node, graph_model, 6.5, false)
    end
end
a = graph_model[89]
pos = 47
SUITE["graph"]["move"]["random"] = @benchmarkable move_agent!($a, $graph_model)
SUITE["graph"]["move"]["pos"] = @benchmarkable move_agent!($a, 68, $graph_model)
SUITE["graph"]["move"]["single"] = @benchmarkable move_agent_single!($a, $graph_model)

# We use a digraph, so all agents are neighbors of each other
SUITE["graph"]["neighbors"]["space_pos"] =
    @benchmarkable space_neighbors($pos, $graph_model) setup =
        (space_neighbors($pos, $graph_model))
SUITE["graph"]["neighbors"]["space_agent"] =
    @benchmarkable space_neighbors($a, $graph_model) setup =
        (space_neighbors($a, $graph_model))
SUITE["graph"]["neighbors"]["space_pos_iterate"] =
    @benchmarkable iterate_over_neighbors($pos, $graph_model, 1) setup =
        (space_neighbors($pos, $graph_model))
SUITE["graph"]["neighbors"]["space_agent_iterate"] =
    @benchmarkable iterate_over_neighbors($a, $graph_model, 1) setup =
        (space_neighbors($a, $graph_model))
SUITE["graph"]["neighbors"]["node_pos"] = @benchmarkable node_neighbors($pos, $graph_model)
SUITE["graph"]["neighbors"]["node_agent"] = @benchmarkable node_neighbors($a, $graph_model)

SUITE["graph"]["node"]["contents"] = @benchmarkable get_node_contents($pos, $graph_model)
SUITE["graph"]["node"]["nodes"] = @benchmarkable nodes($graph_model)

##### API -> GRID ####

grid_model = ABM(GridAgent, GridSpace((1000, 1000)))
grid_agent = GridAgent(1, (2, 3), 6.5, false)
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
SUITE["grid"]["add"]["create_pos"] =
    @benchmarkable add_agent!((1, 3), $grid_model, 6.5, false)
SUITE["grid"]["add"]["create_single"] =
    @benchmarkable add_agent_single!($grid_model, 6.5, false)
SUITE["grid"]["add"]["create"] = @benchmarkable add_agent!($grid_model, 6.5, false)
SUITE["grid"]["add"]["create_fill"] =
    @benchmarkable fill_space!($small_grid_model, 6.5, false)

# Think this is only on current master, will need to rebase
#SUITE["grid"]["add"]["agent_union"] = @benchmarkable add_agent!(GridAgent, $grid_union_model)
SUITE["grid"]["add_union"]["agent"] =
    @benchmarkable add_agent!($grid_agent, $grid_union_model)
SUITE["grid"]["add_union"]["agent_pos"] =
    @benchmarkable add_agent_pos!($grid_agent, $grid_union_model)
SUITE["grid"]["add_union"]["agent_single"] =
    @benchmarkable add_agent_single!($grid_agent, $grid_union_model)
SUITE["grid"]["add_union"]["agent_fill"] =
    @benchmarkable fill_space!(GridAgent, $small_grid_union_model, 6.5, false)

grid_model = ABM(GridAgent, GridSpace((50, 50)))
for x in 1:50
    for y in 1:50
        for _ in 1:4
            add_agent!((x, y), grid_model, 6.5, false)
        end
    end
end
a = grid_model[3709]
pos = (34, 49)
SUITE["grid"]["move"]["random"] = @benchmarkable move_agent!($a, $grid_model)
SUITE["grid"]["move"]["pos"] = @benchmarkable move_agent!($a, (14, 35), $grid_model)
SUITE["grid"]["move"]["single"] = @benchmarkable move_agent_single!($a, $grid_model)

SUITE["grid"]["neighbors"]["space_pos"] =
    @benchmarkable space_neighbors($pos, $grid_model, 5) setup =
        (space_neighbors($pos, $grid_model, 5))
SUITE["grid"]["neighbors"]["space_agent"] =
    @benchmarkable space_neighbors($a, $grid_model, 5) setup =
        (space_neighbors($a, $grid_model, 5))

SUITE["grid"]["neighbors"]["space_pos_iterate"] =
    @benchmarkable iterate_over_neighbors($pos, $grid_model, 30) setup =
        (space_neighbors($pos, $grid_model, 30))

SUITE["grid"]["neighbors"]["space_agent_iterate"] =
    @benchmarkable iterate_over_neighbors($a, $grid_model, 30) setup =
        (space_neighbors($a, $grid_model, 30))

SUITE["grid"]["neighbors"]["node_pos"] = @benchmarkable node_neighbors($a, $grid_model)
SUITE["grid"]["neighbors"]["node_agent"] = @benchmarkable node_neighbors($a, $grid_model)

SUITE["grid"]["node"]["contents"] = @benchmarkable get_node_contents($a, $grid_model)
SUITE["graph"]["node"]["nodes"] = @benchmarkable nodes($graph_model)

#### API -> CONTINUOUS ####

continuous_model = ABM(ContinuousAgent, ContinuousSpace(3; extend = (10.0, 10.0, 10.0)))
continuous_agent = ContinuousAgent(1, (2.2, 1.9, 7.5), (0.5, 1.0, 0.01), 6.5, false)

# We must use setup create the model inside some benchmarks here, otherwise we hit the issue from #226.

SUITE["continuous"]["add"]["agent"] =
    @benchmarkable add_agent!($continuous_agent, cmodel) setup =
        (cmodel = ABM(ContinuousAgent, ContinuousSpace(3; extend = (10.0, 10.0, 10.0))))
SUITE["continuous"]["add"]["agent_pos"] =
    @benchmarkable add_agent_pos!($continuous_agent, cmodel) setup =
        (cmodel = ABM(ContinuousAgent, ContinuousSpace(3; extend = (10.0, 10.0, 10.0))))
SUITE["continuous"]["add"]["create_pos"] = @benchmarkable add_agent!(
    (5.8, 3.5, 9.4),
    $continuous_model,
    (0.9, 0.6, 0.5),
    6.5,
    false,
)
SUITE["continuous"]["add"]["create"] =
    @benchmarkable add_agent!($continuous_model, (0.1, 0.7, 0.2), 6.5, false)

SUITE["continuous"]["add_union"]["agent"] =
    @benchmarkable add_agent!($continuous_agent, cmodel) setup = (
        cmodel = ABM(
            Union{
                ContinuousAgent,
                ContinuousAgentTwo,
                ContinuousAgentThree,
                ContinuousAgentFour,
                ContinuousAgentFive,
            },
            ContinuousSpace(3; extend = (10.0, 10.0, 10.0));
            warn = false,
        )
    )
SUITE["continuous"]["add_union"]["agent_pos"] =
    @benchmarkable add_agent_pos!($continuous_agent, cmodel) setup = (
        cmodel = ABM(
            Union{
                ContinuousAgent,
                ContinuousAgentTwo,
                ContinuousAgentThree,
                ContinuousAgentFour,
                ContinuousAgentFive,
            },
            ContinuousSpace(3; extend = (10.0, 10.0, 10.0));
            warn = false,
        )
    )

for x in range(0, stop = 10.0, length = 12)
    for y in range(0, stop = 10.0, length = 12)
        for z in range(0, stop = 10.0, length = 12)
            add_agent!((x, y, z), continuous_model, (0.8, 0.7, 1.3), 6.5, false)
        end
    end
end
a = continuous_model[1139]
pos = (7.07, 8.10, 6.58)
SUITE["continuous"]["move"]["update"] = @benchmarkable move_agent!($a, $continuous_model)
SUITE["continuous"]["move"]["vel"] =
    @benchmarkable move_agent!($a, $continuous_model, (1.2, 0.0, 0.7))

SUITE["continuous"]["neighbors"]["space_pos"] =
    @benchmarkable space_neighbors($pos, $continuous_model, 5) setup =
        (space_neighbors($pos, $continuous_model, 5))

SUITE["continuous"]["neighbors"]["space_agent"] =
    @benchmarkable space_neighbors($a, $continuous_model, 5) setup =
        (space_neighbors($a, $continuous_model, 5))

SUITE["continuous"]["neighbors"]["space_pos_iterate"] =
    @benchmarkable iterate_over_neighbors($pos, $continuous_model, 10) setup =
        (space_neighbors($pos, $continuous_model, 10))
SUITE["continuous"]["neighbors"]["space_agent_iterate"] =
    @benchmarkable iterate_over_neighbors($a, $continuous_model, 10) setup =
        (space_neighbors($a, $continuous_model, 10))
SUITE["continuous"]["neighbors"]["nearest"] =
    @benchmarkable nearest_neighbor($a, $continuous_model, 5)
SUITE["continuous"]["neighbors"]["interacting"] =
    @benchmarkable interacting_pairs($continuous_model, 1, :scheduler)

#### DATA COLLECTION ###

adata = [:one, :two]
graph_df = init_agent_dataframe(graph_model, adata)
grid_df = init_agent_dataframe(grid_model, adata)
continuous_df = init_agent_dataframe(continuous_model, adata)

SUITE["graph"]["collect"]["init_agent"] =
    @benchmarkable init_agent_dataframe($graph_model, $adata)
SUITE["grid"]["collect"]["init_agent"] =
    @benchmarkable init_agent_dataframe($grid_model, $adata)
SUITE["continuous"]["collect"]["init_agent"] =
    @benchmarkable init_agent_dataframe($continuous_model, $adata)

SUITE["graph"]["collect"]["store_agent"] =
    @benchmarkable collect_agent_data!($graph_df, $graph_model, $adata, 0)
SUITE["grid"]["collect"]["store_agent"] =
    @benchmarkable collect_agent_data!($grid_df, $grid_model, $adata, 0)
SUITE["continuous"]["collect"]["store_agent"] =
    @benchmarkable collect_agent_data!($continuous_df, $continuous_model, $adata, 0)

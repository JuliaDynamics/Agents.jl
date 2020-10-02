using BenchmarkTools, Agents, LightGraphs

const SUITE = BenchmarkGroup(["Agents"])

include("agents.jl")

#### API ###

for space in ["graph", "grid", "continuous"]
    SUITE[space] = BenchmarkGroup(["add", "add_union", "move", "neighbors"])

    SUITE[space]["add"] = BenchmarkGroup(["agent_pos"])
    SUITE[space]["add_union"] = BenchmarkGroup(["agent_pos"])
    if space == "continuous"
        SUITE[space]["move"] = BenchmarkGroup(["update"])
        SUITE[space]["neighbors"] = BenchmarkGroup([
            "nearby_ids",
            "nearby_agents",
            "nearby_ids_iterate",
            "nearby_agents_iterate",
            "nearest",
            #        "interacting",
        ])
    else
        SUITE[space]["move"] = BenchmarkGroup(["random", "pos", "single"])
        SUITE[space]["neighbors"] = BenchmarkGroup([
            "nearby_ids",
            "nearby_agents",
            "nearby_ids_iterate",
            "nearby_agents_iterate",
            "position_pos",
            "position_agent",
        ])
    end
    SUITE[space]["collect"] = BenchmarkGroup(["store_agent"])
end
# some spaces have specific things we'd like to add
push!(SUITE["grid"]["add_union"].tags, "agent_fill")
push!(SUITE["grid"]["add"].tags, "create_fill")
for space in ["grid", "graph"]
    push!(SUITE[space].tags, "position")
    SUITE[space]["position"] = BenchmarkGroup(["contents", "agents"])
end
for add in ["agent", "agent_single"]
    push!(SUITE["graph"]["add"].tags, add)
    push!(SUITE["graph"]["add_union"].tags, add)
end
for add in ["create", "create_pos", "create_single"]
    push!(SUITE["graph"]["add"].tags, add)
end

function iterate_over_neighbors(a, model, r)
    s = 0
    for x in nearby_ids(a, model, r)
        s += x
    end
    return s
end

#### API -> GRAPH ####

graph_model = ABM(GraphAgent, GraphSpace(complete_digraph(200)))
graph_agent = GraphAgent(1, 82, 6.5, false)
graph_union_model = ABM(
    Union{GraphAgent,GraphAgentTwo,GraphAgentThree,GraphAgentFour,GraphAgentFive},
    GraphSpace(complete_digraph(200)),
    warn = false,
)

# Limit samples here so space does not saturate with agents
SUITE["graph"]["add"]["agent"] =
    @benchmarkable add_agent!($graph_agent, $graph_model) samples = 100
SUITE["graph"]["add"]["agent_pos"] =
    @benchmarkable add_agent_pos!($graph_agent, $graph_model) samples = 100
SUITE["graph"]["add"]["agent_single"] =
    @benchmarkable add_agent_single!($graph_agent, $graph_model) samples = 100
SUITE["graph"]["add"]["create_pos"] =
    @benchmarkable add_agent!(26, $graph_model, 6.5, false) samples = 100
SUITE["graph"]["add"]["create_single"] =
    @benchmarkable add_agent_single!($graph_model, 6.5, false) samples = 100
SUITE["graph"]["add"]["create"] =
    @benchmarkable add_agent!($graph_model, 6.5, false) samples = 100

SUITE["graph"]["add_union"]["agent"] =
    @benchmarkable add_agent!($graph_agent, $graph_union_model) samples = 100
SUITE["graph"]["add_union"]["agent_pos"] =
    @benchmarkable add_agent_pos!($graph_agent, $graph_union_model) samples = 100
SUITE["graph"]["add_union"]["agent_single"] =
    @benchmarkable add_agent_single!($graph_agent, $graph_union_model) samples = 100

graph_model = ABM(GraphAgent, GraphSpace(complete_digraph(100)))
for position in 1:100
    for _ in 1:4
        add_agent!(position, graph_model, 6.5, false)
    end
end
a = graph_model[89]
pos = 47
SUITE["graph"]["move"]["random"] = @benchmarkable move_agent!($a, $graph_model)
SUITE["graph"]["move"]["pos"] = @benchmarkable move_agent!($a, 68, $graph_model)
SUITE["graph"]["move"]["single"] = @benchmarkable move_agent_single!($a, $graph_model)

# We use a digraph, so all agents are neighbors of each other
SUITE["graph"]["neighbors"]["nearby_ids"] =
    @benchmarkable nearby_ids($pos, $graph_model) setup = (nearby_ids($pos, $graph_model))
SUITE["graph"]["neighbors"]["nearby_agents"] =
    @benchmarkable nearby_ids($a, $graph_model) setup = (nearby_ids($a, $graph_model))
SUITE["graph"]["neighbors"]["nearby_ids_iterate"] =
    @benchmarkable iterate_over_neighbors($pos, $graph_model, 1) setup =
        (nearby_ids($pos, $graph_model))
SUITE["graph"]["neighbors"]["nearby_agents_iterate"] =
    @benchmarkable iterate_over_neighbors($a, $graph_model, 1) setup =
        (nearby_ids($a, $graph_model))
SUITE["graph"]["neighbors"]["position_pos"] =
    @benchmarkable nearby_positions($pos, $graph_model)
SUITE["graph"]["neighbors"]["position_agent"] =
    @benchmarkable nearby_positions($a, $graph_model)

SUITE["graph"]["position"]["contents"] = @benchmarkable ids_in_position($pos, $graph_model)
SUITE["graph"]["position"]["positions"] = @benchmarkable positions($graph_model)

##### API -> GRID ####

grid_model = ABM(GridAgent, GridSpace((15, 15)))
grid_agent = GridAgent(1, (2, 3), 6.5, false)
grid_union_model = ABM(
    Union{GridAgent,GridAgentTwo,GridAgentThree,GridAgentFour,GridAgentFive},
    GridSpace((15, 15));
    warn = false,
)

SUITE["grid"]["add"]["agent_pos"] =
    @benchmarkable add_agent_pos!($grid_agent, $grid_model) samples = 100
SUITE["grid"]["add"]["create_fill"] =
    @benchmarkable fill_space!($grid_model, 6.5, false) samples = 100

SUITE["grid"]["add_union"]["agent_pos"] =
    @benchmarkable add_agent_pos!($grid_agent, $grid_union_model) samples = 100
SUITE["grid"]["add_union"]["agent_fill"] =
    @benchmarkable fill_space!(GridAgent, $grid_union_model, 6.5, false) samples = 100

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

SUITE["grid"]["neighbors"]["nearby_ids"] =
    @benchmarkable nearby_ids($pos, $grid_model, 5) setup =
        (nearby_ids($pos, $grid_model, 5))
SUITE["grid"]["neighbors"]["nearby_agents"] =
    @benchmarkable nearby_ids($a, $grid_model, 5) setup = (nearby_ids($a, $grid_model, 5))

SUITE["grid"]["neighbors"]["nearby_ids_iterate"] =
    @benchmarkable iterate_over_neighbors($pos, $grid_model, 30) setup =
        (nearby_ids($pos, $grid_model, 30))

SUITE["grid"]["neighbors"]["nearby_agents_iterate"] =
    @benchmarkable iterate_over_neighbors($a, $grid_model, 30) setup =
        (nearby_ids($a, $grid_model, 30))

SUITE["grid"]["neighbors"]["position_pos"] =
    @benchmarkable nearby_positions($a, $grid_model)
SUITE["grid"]["neighbors"]["position_agent"] =
    @benchmarkable nearby_positions($a, $grid_model)

SUITE["grid"]["position"]["contents"] = @benchmarkable ids_in_position($pos, $grid_model)
SUITE["graph"]["position"]["positions"] = @benchmarkable positions($graph_model)

#### API -> CONTINUOUS ####

continuous_model = ABM(ContinuousAgent, CompartmentSpace((10.0, 10.0, 10.0), 0.5))
continuous_agent = ContinuousAgent(1, (2.2, 1.9, 7.5), (0.5, 1.0, 0.01), 6.5, false)

# We must use setup create the model inside some benchmarks here, otherwise we hit the issue from #226.
# For tuning, this is actually impossible. So until CompartmentSpace is implemented, we drop these tests.
SUITE["continuous"]["add"]["agent_pos"] =
    @benchmarkable add_agent_pos!($continuous_agent, cmodel) setup =
        (cmodel = ABM(ContinuousAgent, CompartmentSpace((10.0, 10.0, 10.0), 0.5))) samples =
        100

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
            CompartmentSpace((10.0, 10.0, 10.0), 0.5);
            warn = false,
        )
    ) samples = 100

for x in range(0, stop = 9.99, length = 7)
    for y in range(0, stop = 9.99, length = 7)
        for z in range(0, stop = 9.99, length = 7)
            add_agent!((x, y, z), continuous_model, (0.8, 0.7, 1.3), 6.5, false)
        end
    end
end
a = continuous_model[139]
pos = (7.07, 8.10, 6.58)
SUITE["continuous"]["move"]["update"] = @benchmarkable move_agent!($a, $continuous_model)

SUITE["continuous"]["neighbors"]["nearby_ids"] =
    @benchmarkable nearby_ids($pos, $continuous_model, 5) setup =
        (nearby_ids($pos, $continuous_model, 5))

SUITE["continuous"]["neighbors"]["nearby_agents"] =
    @benchmarkable nearby_ids($a, $continuous_model, 5) setup =
        (nearby_ids($a, $continuous_model, 5))

SUITE["continuous"]["neighbors"]["nearby_ids_iterate"] =
    @benchmarkable iterate_over_neighbors($pos, $continuous_model, 10) setup =
        (nearby_ids($pos, $continuous_model, 10))
SUITE["continuous"]["neighbors"]["nearby_agents_iterate"] =
    @benchmarkable iterate_over_neighbors($a, $continuous_model, 10) setup =
        (nearby_ids($a, $continuous_model, 10))
SUITE["continuous"]["neighbors"]["nearest"] =
    @benchmarkable nearest_neighbor($a, $continuous_model, 5)

# Benchmark takes too long to be reasonable, even with a small sample.
# This needs to be looked at in the future, but it's being ignored for the moment
# (until CompartmentSpace is implemented)
#genocide!(continuous_model, 50)
#SUITE["continuous"]["neighbors"]["interacting"] =
#@benchmarkable interacting_pairs($continuous_model, 3, :all) samples=5 seconds=60

#### DATA COLLECTION ###

adata = [:one, :two]
graph_df = init_agent_dataframe(graph_model, adata)
grid_df = init_agent_dataframe(grid_model, adata)
continuous_df = init_agent_dataframe(continuous_model, adata)

SUITE["graph"]["collect"]["store_agent"] =
    @benchmarkable collect_agent_data!($graph_df, $graph_model, $adata, 0)
SUITE["grid"]["collect"]["store_agent"] =
    @benchmarkable collect_agent_data!($grid_df, $grid_model, $adata, 0)
SUITE["continuous"]["collect"]["store_agent"] =
    @benchmarkable collect_agent_data!($continuous_df, $continuous_model, $adata, 0)



# The following simple model has a variable number of agent types,
# but there is no removing or creating of additional agents.
# It creates a model that has the same number of agents and does
# overall the same number of operations, but these operations
# are split in a varying number of agents. It shows how much of a
# performance hit is to have many different agent types.

using Agents, Random, BenchmarkTools

@agent struct Agent1(GridAgent{2})
    money::Int
end

@agent struct Agent2(GridAgent{2})
    money::Int
end

@agent struct Agent3(GridAgent{2})
    money::Int
end

@agent struct Agent4(GridAgent{2})
    money::Int
end

@agent struct Agent5(GridAgent{2})
    money::Int
end

@agent struct Agent6(GridAgent{2})
    money::Int
end

@agent struct Agent7(GridAgent{2})
    money::Int
end

@agent struct Agent8(GridAgent{2})
    money::Int
end

@agent struct Agent9(GridAgent{2})
    money::Int
end

@agent struct Agent10(GridAgent{2})
    money::Int
end

@agent struct Agent11(GridAgent{2})
    money::Int
end

@agent struct Agent12(GridAgent{2})
    money::Int
end

@agent struct Agent13(GridAgent{2})
    money::Int
end

@agent struct Agent14(GridAgent{2})
    money::Int
end

@agent struct Agent15(GridAgent{2})
    money::Int
end

@multiagent :opt_memory struct AgentAllMemory(GridAgent{2})
    @agent struct Agent1m
        money::Int
    end
    @agent struct Agent2m
        money::Int
    end
    @agent struct Agent3m
        money::Int
    end
    @agent struct Agent4m
        money::Int
    end
    @agent struct Agent5m
        money::Int
    end
    @agent struct Agent6m
        money::Int
    end
    @agent struct Agent7m
        money::Int
    end
    @agent struct Agent8m
        money::Int
    end
    @agent struct Agent9m
        money::Int
    end
    @agent struct Agent10m
        money::Int
    end
    @agent struct Agent11m
        money::Int
    end
    @agent struct Agent12m
        money::Int
    end
    @agent struct Agent13m
        money::Int
    end
    @agent struct Agent14m
        money::Int
    end
    @agent struct Agent15m
        money::Int
    end
end

@multiagent :opt_speed struct AgentAllSpeed(GridAgent{2})
    @agent struct Agent1s
        money::Int
    end
    @agent struct Agent2s
        money::Int
    end
    @agent struct Agent3s
        money::Int
    end
    @agent struct Agent4s
        money::Int
    end
    @agent struct Agent5s
        money::Int
    end
    @agent struct Agent6s
        money::Int
    end
    @agent struct Agent7s
        money::Int
    end
    @agent struct Agent8s
        money::Int
    end
    @agent struct Agent9s
        money::Int
    end
    @agent struct Agent10s
        money::Int
    end
    @agent struct Agent11s
        money::Int
    end
    @agent struct Agent12s
        money::Int
    end
    @agent struct Agent13s
        money::Int
    end
    @agent struct Agent14s
        money::Int
    end
    @agent struct Agent15s
        money::Int
    end
end

function initialize_model_1(;n_agents=600,dims=(5,5))
    space = GridSpace(dims)
    model = StandardABM(Agent1, space; agent_step!,
                        scheduler=Schedulers.Randomly(),
                        rng = Xoshiro(42), warn=false)
    id = 0
    for id in 1:n_agents
        add_agent!(Agent1, model, 10)
    end
    return model
end

function initialize_model_15_multi_memory(;n_agents=600, dims=(5,5))
    agent_types = [Agent1m,Agent2m,Agent3m,Agent4m,Agent5m,Agent6m,Agent7m,Agent8m,
                   Agent9m,Agent10m,Agent11m,Agent12m,Agent13m,Agent14m,Agent15m]
    agents_used = agent_types[1:15]
    space = GridSpace(dims)
    model = StandardABM(AgentAllMemory, space; agent_step!,
                        scheduler=Schedulers.Randomly(), warn=false,
                        rng = Xoshiro(42))
    agents_per_type = div(n_agents, 15)
    for A in agents_used
        for _ in 1:agents_per_type
            add_agent!(A, model, 10)
        end
    end
    return model
end

function initialize_model_15_multi_speed(;n_agents=600, dims=(5,5))
    agent_types = [Agent1s,Agent2s,Agent3s,Agent4s,Agent5s,Agent6s,Agent7s,Agent8s,
                   Agent9s,Agent10s,Agent11s,Agent12s,Agent13s,Agent14s,Agent15s]
    agents_used = agent_types[1:15]
    space = GridSpace(dims)
    model = StandardABM(AgentAllSpeed, space; agent_step!,
                        scheduler=Schedulers.Randomly(), warn=false,
                        rng = Xoshiro(42))
    agents_per_type = div(n_agents, 15)
    for A in agents_used
        for _ in 1:agents_per_type
            add_agent!(A, model, 10)
        end
    end
    return model
end

function initialize_model_n(;n_agents=600, n_types=1, dims=(5,5))
    agent_types = [Agent1,Agent2,Agent3,Agent4,Agent5,Agent6,Agent7,Agent8,
        Agent9,Agent10,Agent11,Agent12,Agent13,Agent14,Agent15]
    agents_used = agent_types[1:n_types]
    space = GridSpace(dims)
    model = StandardABM(Union{agents_used...}, space; agent_step!,
                        scheduler=Schedulers.Randomly(), warn=false,
                        rng = Xoshiro(42))
    agents_per_type = div(n_agents, n_types)
    for A in agents_used
        for _ in 1:agents_per_type
            add_agent!(A, model, 10)
        end
    end
    return model
end

function agent_step!(agent, model)
    move!(agent, model)
    agents = agents_in_position(agent.pos, model)
    for a in agents; exchange!(agent, a); end
    return nothing
end

function move!(agent, model)
    neighbors = nearby_positions(agent, model)
    cell = rand(abmrng(model), collect(neighbors))
    move_agent!(agent, cell, model)
    return nothing
end

function exchange!(agent, other_agent)
    v1 = agent.money
    v2 = other_agent.money
    agent.money = v2
    other_agent.money = v1
    return nothing
end

function run_simulation_1(n_steps)
    model = initialize_model_1()
    Agents.step!(model, n_steps)
end

function run_simulation_15_multi_memory(n_steps)
    model = initialize_model_15_multi_memory()
    Agents.step!(model, n_steps)
end
function run_simulation_15_multi_speed(n_steps)
    model = initialize_model_15_multi_speed()
    Agents.step!(model, n_steps)
end

function run_simulation_n(n_steps; n_types)
    model = initialize_model_n(; n_types=n_types)
    Agents.step!(model, n_steps)
end

# %% Run the simulation, do performance estimate, first with 1, then with many
n_steps = 50
n_types = [2,3,4,5,10,15]

time_1 = @belapsed run_simulation_1($n_steps)
times = Float64[]
for n in n_types
    println(n)
    t = @belapsed run_simulation_n($n_steps; n_types=$n)
    push!(times, t/time_1)
end
t_multi = @belapsed run_simulation_15_multi_memory($n_steps)
t_multi_rel = t_multi/time_1

t_multi_speed = @belapsed run_simulation_15_multi_speed($n_steps)
t_multi_rel_speed = t_multi_speed/time_1

println("relative time of model with 1 type: 1")
for (n, t) in zip(n_types, times)
    println("relative time of model with $n types: $t")
end
println("relative time of model with @multiagent :opt_memory: $t_multi_rel")
println("relative time of model with @multiagent :opt_speed: $t_multi_rel_speed")

# relative time of model with 1 type: 1
#
# relative time of model with 2 types: 1.287252249521869
# relative time of model with 3 types: 1.4146741156162865
# relative time of model with 4 types: 4.059042824599718
# relative time of model with 5 types: 5.243935156955378
# relative time of model with 10 types: 7.694527211389013
# relative time of model with 15 types: 11.243909260086886
#
# relative time of model with @multiagent :opt_speed: 1.004122351734208
# relative time of model with @multiagent :opt_memory: 2.8898100796366544

using CairoMakie
fig, ax = CairoMakie.scatterlines(n_types, times; label = "Union");
scatter!(ax, 15, t_multi_rel; color = Cycled(2), marker = :circle, markersize = 12, label = "@multi; opt_memory")
scatter!(ax, 15, t_multi_rel_speed; color = Cycled(4), marker = :rect, markersize = 12, label = "@multi; opt_speed")
scatter!(ax, n_types, times)
ax.xlabel = "# types"
ax.ylabel = "time relative to 1 type"
ax.title = "Union types vs @multiagent macro"
axislegend(ax; position = :lt)
ax.yticks = 0:1:ceil(Int, maximum(times))
ax.xticks = 2:2:16
fig

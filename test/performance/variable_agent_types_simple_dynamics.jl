
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

agents_m = [Symbol(:AgentAllMemory, :($y)) for y in [2,3,4,5,10,15]]
subagents_m = [[Symbol(:Agent, :($x), :m, :($y)) for x in 1:y] for y in [2,3,4,5,10,15]]
expr_subagents_m = [[:(@subagent struct $(Symbol(:Agent, :($x), :m, :($y)))
                            money::Int
                       end) for x in 1:y] for y in [2,3,4,5,10,15]]
for (a, subs) in zip(agents_m, expr_subagents_m)
    @eval @multiagent :opt_memory struct $a(GridAgent{2})
        $(subs...)
    end
end

agents_s = [Symbol(:AgentAllSpeed, :($y)) for y in [2,3,4,5,10,15]]
subagents_s = [[Symbol(:Agent, :($x), :s, :($y)) for x in 1:y] for y in [2,3,4,5,10,15]]
expr_subagents_s = [[:(@subagent struct $(Symbol(:Agent, :($x), :s, :($y)))
                           money::Int
                       end) for x in 1:y] for y in [2,3,4,5,10,15]]
for (a, subs) in zip(agents_s, expr_subagents_s)
    @eval @multiagent :opt_speed struct $a(GridAgent{2})
        $(subs...)
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

function initialize_model_multi_memory(;n_agents=600, n_types=1, dims=(5,5))
    i = findfirst(x -> length(x) == n_types, subagents_m)
    agents_used = [eval(sa) for sa in subagents_m[i]]
    space = GridSpace(dims)
    model = StandardABM(eval(agents_m[i]), space; agent_step!,
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

function initialize_model_multi_speed(;n_agents=600, n_types=1, dims=(5,5))
    i = findfirst(x -> length(x) == n_types, subagents_s)
    agents_used = [eval(sa) for sa in subagents_s[i]]
    space = GridSpace(dims)
    model = StandardABM(eval(agents_s[i]), space; agent_step!,
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

function run_simulation_multi_memory(n_steps; n_types)
    model = initialize_model_multi_memory(; n_types=n_types)
    Agents.step!(model, n_steps)
end
function run_simulation_multi_speed(n_steps; n_types)
    model = initialize_model_multi_speed(; n_types=n_types)
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
times_n = Float64[]
times_multi_m = Float64[]
times_multi_s = Float64[]
for n in n_types
    println(n)
    t = @belapsed run_simulation_n($n_steps; n_types=$n)
    push!(times_n, t/time_1)
    t_multi = @belapsed run_simulation_multi_memory($n_steps; n_types=$n)
    push!(times_multi_m, t_multi/time_1)
    t_multi_speed = @belapsed run_simulation_multi_speed($n_steps; n_types=$n)
    push!(times_multi_s, t_multi_speed/time_1)
end

println("relative time of model with 1 type: 1")
for (n, t1, t2, t3) in zip(n_types, times_n, times_multi_m, times_multi_s)
    println("relative time of model with $n types: $t1")
    println("relative time of model with $n @multiagent :opt_memory: $t2")
    println("relative time of model with $n @multiagent :opt_speed: $t3")
end

using CairoMakie
fig, ax = CairoMakie.scatterlines(n_types, times_n; label = "Union");
scatterlines!(ax, n_types, times_multi_s; label = "@multi :opt_speed")
scatterlines!(ax, n_types, times_multi_m; label = "@multi :opt_memory")
ax.xlabel = "# types"
ax.ylabel = "time relative to 1 type"
ax.title = "Union types vs @multiagent macro"
axislegend(ax; position = :lt)
ax.yticks = 0:1:ceil(Int, maximum(times_n))
ax.xticks = 2:2:16
fig

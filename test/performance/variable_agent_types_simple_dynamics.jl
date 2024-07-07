
# The following simple model has a variable number of agent types,
# but there is no removing or creating of additional agents.
# It creates a model that has the same number of agents and does
# overall the same number of operations, but these operations
# are split in a varying number of agents. It shows how much of a
# performance hit is to have many different agent types.

using Agents, DynamicSumTypes, Random, BenchmarkTools

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

@sumtype AgentAll2(Agent1, Agent2) <: AbstractAgent
@sumtype AgentAll3(Agent1, Agent2, Agent3) <: AbstractAgent
@sumtype AgentAll4(Agent1, Agent2, Agent3, Agent4) <: AbstractAgent
@sumtype AgentAll5(Agent1, Agent2, Agent3, Agent4, Agent5) <: AbstractAgent
@sumtype AgentAll10(Agent1, Agent2, Agent3, Agent4, Agent5, Agent6, 
    Agent7, Agent8, Agent9, Agent10) <: AbstractAgent
@sumtype AgentAll15(Agent1, Agent2, Agent3, Agent4, Agent5, Agent6, 
    Agent7, Agent8, Agent9, Agent10, Agent11, Agent12, Agent13, Agent14, Agent15) <: AbstractAgent

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

function initialize_model_sum(;n_agents=600, n_types=1, dims=(5,5))
    agent_types = [Agent1,Agent2,Agent3,Agent4,Agent5,Agent6,Agent7,Agent8,
        Agent9,Agent10,Agent11,Agent12,Agent13,Agent14,Agent15]
    agents_used = agent_types[1:n_types]
    agent_all_t = Dict(2 => AgentAll2, 3 => AgentAll3, 
                       4 => AgentAll4, 5 => AgentAll5,
                       10 => AgentAll10, 15 => AgentAll15)
    agent_all = agent_all_t[n_types]
    space = GridSpace(dims)
    model = StandardABM(agent_all, space; agent_step!,
                        scheduler=Schedulers.Randomly(), warn=false,
                        rng = Xoshiro(42))
    agents_per_type = div(n_agents, n_types)
    for A in agents_used
        for _ in 1:agents_per_type
            agent = agent_all(A(model, random_position(model), 10))
            add_agent_own_pos!(agent, model)
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

function run_simulation_sum(n_steps; n_types)
    model = initialize_model_sum(; n_types=n_types)
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
times_multi_s = Float64[]
for n in n_types
    println(n)
    t = @belapsed run_simulation_n($n_steps; n_types=$n)
    push!(times_n, t/time_1)
    t_sum = @belapsed run_simulation_sum($n_steps; n_types=$n)
    print(t/time_1, " ", t_sum/time_1)
    push!(times_multi_s, t_sum/time_1)
end

println("relative time of model with 1 type: 1.0")
for (n, t1, t2) in zip(n_types, times_n, times_multi_s)
    println("relative time of model with $n types: $t1")
    println("relative time of model with $n @sumtype: $t2")
end

using CairoMakie
fig, ax = CairoMakie.scatterlines(n_types, times_n; label = "Union");
scatterlines!(ax, n_types, times_multi_s; label = "@sumtype")
ax.xlabel = "# types"
ax.ylabel = "time relative to 1 type"
ax.title = "Union types vs @sumtype"
axislegend(ax; position = :lt)
ax.yticks = 0:1:ceil(Int, maximum(times_n))
ax.xticks = [2, 3, 4, 5, 10, 15]
fig

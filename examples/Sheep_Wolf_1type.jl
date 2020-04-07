using Revise, Agents, DataFrames, Random, StatsPlots

mutable struct Agent <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    agent_type::Symbol
    energy::Float64
    countdown::Int
    reproduction_prob::Float64
    Δenergy::Float64
    fully_grown::Bool
    regrowth_time::Int
end

function Agent(id, pos; agent_type, energy=10, countdown=30, reproduction_prob=.04, Δenergy=4.0,
    fully_grown=false, regrowth_time=30)
    return Agent(id, pos, agent_type, energy, countdown, reproduction_prob, Δenergy, fully_grown, regrowth_time)
end

function initialize_model(;n_sheep=100, n_wolves=50, dims=(20,20), regrowth_time=30,
    Δenergy_sheep=4, Δenergy_wolf=20, sheep_reproduce=.04, wolf_reproduce=.05)
    space = GridSpace(dims)
    properties = Dict(:step=>0)
    model = ABM(Agent, space, properties=properties, scheduler=random_activation)
    for _ in 1:n_sheep
        energy = rand(1:Δenergy_sheep*2) - 1
        add_agent!(model; agent_type=:sheep, reproduction_prob=sheep_reproduce,
            Δenergy=Δenergy_sheep, energy=energy)
    end
    for _ in 1:n_wolves
        energy = rand(1:Δenergy_wolf*2) - 1
        add_agent!(model; agent_type=:wolf, reproduction_prob=wolf_reproduce,
            Δenergy=Δenergy_wolf, energy=energy)
    end
    for n in nodes(model)
        fully_grown = rand(Bool)
        fully_grown ? countdown = regrowth_time : countdown = rand(1:regrowth_time) - 1
        add_agent!(n, model; agent_type=:grass, fully_grown=fully_grown, regrowth_time=regrowth_time,
            countdown=countdown)
    end
    return model
end

function move!(agent, model)
    neighbors = node_neighbors(agent, model)
    cell = rand(neighbors)
    move_agent!(agent, cell, model)
end

function eat_sheep!(wolf, sheep, model)
    if !isempty(sheep)
        dinner = rand(sheep)
        kill_agent!(dinner, model)
        wolf.energy += wolf.Δenergy
    end
end

function eat_grass!(sheep, grass, model)
    if !isempty(grass)
        dinner = rand(grass)
        dinner.fully_grown = false
        sheep.energy += sheep.Δenergy
    end
end

function agent_step!(agent, model)
    if agent.agent_type == :sheep
        sheep_step!(agent, model)
    elseif agent.agent_type == :wolf
        wolf_step!(agent, model)
    else
        grass_step!(agent, model)
    end
end

function sheep_step!(sheep, model)
    move!(sheep, model)
    sheep.energy -= 1
    agents = get_node_agents(sheep.pos, model)
    dinner = filter!(x->(x.agent_type == :grass) && x.fully_grown, agents)
    eat_grass!(sheep, dinner, model)
    if sheep.energy <= 0
        kill_agent!(sheep, model)
        return nothing
    end
    if rand() <= sheep.reproduction_prob
        reproduce!(sheep, model)
        return nothing
    end
end

function wolf_step!(wolf, model)
    move!(wolf, model)
    wolf.energy -= 1
    agents = get_node_agents(wolf.pos, model)
    dinner = filter!(x->x.agent_type == :sheep, agents)
    eat_sheep!(wolf, dinner, model)
    if wolf.energy <= 0
        kill_agent!(wolf, model)
        return nothing
    end
    if rand() <= wolf.reproduction_prob
        reproduce!(wolf, model)
        return nothing
    end
end

function grass_step!(grass, model)
    if !grass.fully_grown
        if grass.countdown <= 0
            grass.fully_grown = true
            grass.countdown = grass.regrowth_time
        else
            grass.countdown -= 1
        end
    end
end

function reproduce!(agent, model)
    agent.energy /= 2
    energy = rand(1:agent.Δenergy*2) - 1
    add_agent!(model; agent_type=agent.agent_type, energy=energy,
    reproduction_prob=agent.reproduction_prob, Δenergy=agent.Δenergy)
end

function model_step!(model, df)
    agents = values(model.agents)
    model.properties[:step] += 1
    step = model.properties[:step]
    n_sheep = count(x->x.agent_type == :sheep, agents)
    n_wolves = count(x->x.agent_type == :wolf, agents)
    n_grass = count(x->(x.agent_type == :grass) && x.fully_grown, agents)
    push!(df, [step n_sheep n_wolves n_grass])
end


n_steps = 500
Random.seed!(2514)
model = initialize_model()
results = DataFrame(step=Int[], n_sheep=Int[], n_wolves=Int[], n_grass=Int[])
step!(model, agent_step!, x->model_step!(x, results), n_steps)

pyplot()
@df results plot(:step, :n_sheep, grid=false, xlabel="Step",
    ylabel="Population", label="Sheep")
@df results plot!(:step, :n_wolves, label="Wolves")
@df results plot!(:step, :n_grass, label="Grass")

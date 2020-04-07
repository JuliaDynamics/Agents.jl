using Revise, Agents, DataFrames, Random, StatsPlots

mutable struct Sheep <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    energy::Float64
    reproduction_prob::Float64
    Δenergy::Float64
end

function Sheep(id=0, pos=(0,0); energy=10, reproduction_prob=.04, Δenergy=4.0)
    return Sheep(id, pos, energy, reproduction_prob, Δenergy)
end

mutable struct Wolf <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    energy::Float64
    reproduction_prob::Float64
    Δenergy::Float64
end

function Wolf(id=0, pos=(0,0); energy=10, reproduction_prob=.04, Δenergy=4.0)
    return Wolf(id, pos, energy, reproduction_prob, Δenergy)
end

mutable struct Grass <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    fully_grown::Bool
    regrowth_time::Int
    countdown::Int
end

function Grass(id=0, pos=(0,0); fully_grown=false, regrowth_time=30, countdown=0)
    return Grass(id, pos, fully_grown, regrowth_time, countdown)
end

function initialize_model(;n_sheep=100, n_wolves=50, dims=(20,20), regrowth_time=30,
    Δenergy_sheep=4, Δenergy_wolf=20, sheep_reproduce=.04, wolf_reproduce=.05)
    space = GridSpace(dims)
    properties = Dict(:step=>0)
    model = ABM(Union{Sheep,Wolf,Grass}, space, properties=properties, scheduler=random_activation, warn=false)
    id = 0
    for _ in 1:n_sheep
        id += 1
        energy = rand(1:Δenergy_sheep*2) - 1
        sheep = Sheep(id, reproduction_prob=sheep_reproduce, Δenergy=Δenergy_sheep, energy=energy)
        add_agent!(sheep, model)
    end
    for _ in 1:n_wolves
        id += 1
        energy = rand(1:Δenergy_wolf*2) - 1
        wolf = Wolf(id, reproduction_prob=wolf_reproduce, Δenergy=Δenergy_wolf, energy=energy)
        add_agent!(wolf, model)
    end
    for n in nodes(model)
        id += 1
        fully_grown = rand(Bool)
        fully_grown ? countdown = regrowth_time : countdown = rand(1:regrowth_time) - 1
        grass = Grass(id, fully_grown=fully_grown, regrowth_time=regrowth_time, countdown=countdown)
        add_agent!(grass, n, model)
    end
    return model
end

function move!(agent, model)
    neighbors = node_neighbors(agent, model)
    cell = rand(neighbors)
    move_agent!(agent, cell, model)
end

function eat!(wolf::Wolf, sheep, model)
    if !isempty(sheep)
        dinner = rand(sheep)
        kill_agent!(dinner, model)
        wolf.energy += wolf.Δenergy
    end
end

function eat!(sheep::Sheep, grass_array, model)
    isempty(grass_array) ? (return nothing) : nothing
    grass = grass_array[1]
    if grass.fully_grown
        sheep.energy += sheep.Δenergy
        grass.fully_grown = false
        grass.countdown = grass.regrowth_time
    end
end

function agent_step!(sheep::Sheep, model)
    move!(sheep, model)
    sheep.energy -= 1
    agents = get_node_agents(sheep.pos, model)
    dinner = filter!(x->isa(x, Grass), agents)
    eat!(sheep, dinner, model)
    if sheep.energy <= 0
        kill_agent!(sheep, model)
        return nothing
    end
    if rand() <= sheep.reproduction_prob
        reproduce!(sheep, model)
    end
end

function agent_step!(wolf::Wolf, model)
    move!(wolf, model)
    wolf.energy -= 1
    agents = get_node_agents(wolf.pos, model)
    dinner = filter!(x->isa(x, Sheep), agents)
    eat!(wolf, dinner, model)
    if wolf.energy <= 0
        kill_agent!(wolf, model)
        return nothing
    end
    if rand() <= wolf.reproduction_prob
        reproduce!(wolf, model)
        return nothing
    end
end

function agent_step!(grass::Grass, model)
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
    id = nextid(model)
    energy = rand(1:agent.Δenergy*2) - 1
    A = typeof(agent)
    baby = A(id, reproduction_prob=agent.reproduction_prob,
        Δenergy=agent.Δenergy, energy=energy)
    add_agent!(baby, model)
    return nothing
end


function model_step!(model, df)
    agents = values(model.agents)
    model.properties[:step] += 1
    step = model.properties[:step]
    n_sheep = count(x->typeof(x) == Sheep, agents)
    n_wolves = count(x->typeof(x) == Wolf, agents)
    n_grass = count(x->(typeof(x) == Grass) && x.fully_grown, agents)
    push!(df, [step n_sheep n_wolves n_grass])
end


n_steps = 500
Random.seed!(23182)
model = initialize_model()
results = DataFrame(step=Int[], n_sheep=Int[], n_wolves=Int[], n_grass=Int[])
step!(model, agent_step!, x->model_step!(x, results), n_steps)

pyplot()
@df results plot(:step, :n_sheep, grid=false, xlabel="Step",
    ylabel="Population", label="Sheep")
@df results plot!(:step, :n_wolves, label="Wolves")
@df results plot!(:step, :n_grass, label="Grass")

using AgentsPlots
Random.seed!(23182)
properties = [:pos,x->typeof(x)]
run!(model, agent_step!, n_steps; agent_properties=properties)

p = plot2D(results, :n_sheep, t = 1, nodesize = 10)

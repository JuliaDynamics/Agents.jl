using Agents, DataFrames, Random, StatsPlots

mutable struct Sheep <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    energy::Float64
    reproduction_prob::Float64
    Δenergy::Float64
end

mutable struct Wolf <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    energy::Float64
    reproduction_prob::Float64
    Δenergy::Float64
end

mutable struct Grass <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    fully_grown::Bool
    regrowth_time::Int
    countdown::Int
end

# randomize with the constraint that types must be together
function by_breed(model::ABM)
    c = [Int[], Int[], Int[]] # first=wolf, second=sheep
    for a in allagents(model)
        j = a isa Wolf ? 1 : a isa Sheep ? 2 : 3
        push!(c[j], a.id)
    end
    for i in c; shuffle!(i); end
    shuffle!(c)
    return vcat(c...)
end

function initialize_model(;n_sheep=100, n_wolves=50, dims=(20,20), regrowth_time=30,
    Δenergy_sheep=4, Δenergy_wolf=20, sheep_reproduce=.04, wolf_reproduce=.05)
    space = GridSpace(dims, moore = true)
    properties = Dict(:step=>0)
    model = ABM(Union{Sheep,Wolf,Grass}, space, properties=properties, scheduler=by_breed, warn=false)
    id = 0
    for _ in 1:n_sheep
        id += 1
        energy = rand(1:Δenergy_sheep*2) - 1
        sheep = Sheep(id, (0,0), energy, sheep_reproduce, Δenergy_sheep)
        add_agent!(sheep, model)
    end
    for _ in 1:n_wolves
        id += 1
        energy = rand(1:Δenergy_wolf*2) - 1
        wolf = Wolf(id, (0,0), energy, wolf_reproduce, Δenergy_wolf)
        add_agent!(wolf, model)
    end
    for n in nodes(model)
        id += 1
        fully_grown = rand(Bool)
        fully_grown ? countdown = regrowth_time : countdown = rand(1:regrowth_time) - 1
        grass = Grass(id, (0,0), fully_grown, regrowth_time, countdown)
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
    spawn = A(id, agent.pos, energy, agent.reproduction_prob, agent.Δenergy)
    add_agent_pos!(spawn, model)
    return nothing
end

n_steps = 500
Random.seed!(23182)
model = initialize_model()
sheep(a) = typeof(a) == Sheep
wolves(a) = typeof(a) == Wolf
grass(a) = typeof(a) == Grass && a.fully_grown
adata = [(sheep, count), (wolves, count), (grass, count)]
results, _ = run!(model, agent_step!, n_steps; adata = adata)

pyplot()
@df results plot(:step, cols(Symbol("count(sheep)")), grid=false, xlabel="Step",
    ylabel="Population", label="Sheep")
@df results plot!(:step, cols(Symbol("count(wolves)")), label="Wolves")
@df results plot!(:step, cols(Symbol("count(grass)")), label="Grass")

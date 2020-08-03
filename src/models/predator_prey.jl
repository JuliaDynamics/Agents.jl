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

"""
``` julia
predator_prey(; 
    n_sheep = 100,
    n_wolves = 50,
    dims = (20, 20),
    regrowth_time = 30,
    Δenergy_sheep = 4,
    Δenergy_wolf = 20,
    sheep_reproduce = 0.04,
    wolf_reproduce = 0.05,
)
```
Same as in [Model of predator-prey dynamics](@ref).
"""
function predator_prey(;
    n_sheep = 100,
    n_wolves = 50,
    dims = (20, 20),
    regrowth_time = 30,
    Δenergy_sheep = 4,
    Δenergy_wolf = 20,
    sheep_reproduce = 0.04,
    wolf_reproduce = 0.05,
)
    space = GridSpace(dims, moore = true)
    model =
        ABM(Union{Sheep,Wolf,Grass}, space, scheduler = by_type(true, true), warn = false)
    id = 0
    for _ in 1:n_sheep
        id += 1
        energy = rand(1:(Δenergy_sheep * 2)) - 1
        ## Note that we must instantiate agents before adding them in a mixed-ABM
        ## to confirm their type.
        sheep = Sheep(id, (0, 0), energy, sheep_reproduce, Δenergy_sheep)
        add_agent!(sheep, model)
    end
    for _ in 1:n_wolves
        id += 1
        energy = rand(1:(Δenergy_wolf * 2)) - 1
        wolf = Wolf(id, (0, 0), energy, wolf_reproduce, Δenergy_wolf)
        add_agent!(wolf, model)
    end
    for n in nodes(model)
        id += 1
        fully_grown = rand(Bool)
        countdown = fully_grown ? regrowth_time : rand(1:regrowth_time) - 1
        grass = Grass(id, (0, 0), fully_grown, regrowth_time, countdown)
        add_agent!(grass, n, model)
    end
    return model, predator_prey_agent_step!, dummystep
end

function predator_prey_agent_step!(sheep::Sheep, model)
    move!(sheep, model)
    sheep.energy -= 1
    agents = get_node_agents(sheep.pos, model)
    dinner = filter!(x -> isa(x, Grass), agents)
    eat!(sheep, dinner, model)
    if sheep.energy < 0
        kill_agent!(sheep, model)
        return
    end
    if rand() <= sheep.reproduction_prob
        reproduce!(sheep, model)
    end
end

function predator_prey_agent_step!(wolf::Wolf, model)
    move!(wolf, model)
    wolf.energy -= 1
    agents = get_node_agents(wolf.pos, model)
    dinner = filter!(x -> isa(x, Sheep), agents)
    eat!(wolf, dinner, model)
    if wolf.energy < 0
        kill_agent!(wolf, model)
        return
    end
    if rand() <= wolf.reproduction_prob
        reproduce!(wolf, model)
    end
end

function predator_prey_agent_step!(grass::Grass, model)
    if !grass.fully_grown
        if grass.countdown <= 0
            grass.fully_grown = true
            grass.countdown = grass.regrowth_time
        else
            grass.countdown -= 1
        end
    end
end

function move!(agent, model)
    neighbors = node_neighbors(agent, model)
    cell = rand(neighbors)
    move_agent!(agent, cell, model)
end

function eat!(sheep::Sheep, grass_array, model)
    isempty(grass_array) && return
    grass = grass_array[1]
    if grass.fully_grown
        sheep.energy += sheep.Δenergy
        grass.fully_grown = false
    end
end

function eat!(wolf::Wolf, sheep, model)
    if !isempty(sheep)
        dinner = rand(sheep)
        kill_agent!(dinner, model)
        wolf.energy += wolf.Δenergy
    end
end

function reproduce!(agent, model)
    agent.energy /= 2
    id = nextid(model)
    A = typeof(agent)
    offspring = A(id, agent.pos, agent.energy, agent.reproduction_prob, agent.Δenergy)
    add_agent_pos!(offspring, model)
    return
end
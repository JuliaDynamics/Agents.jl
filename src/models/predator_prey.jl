export Sheep, Wolf, Grass

mutable struct Sheep <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    energy::Float64
end

mutable struct Wolf <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    energy::Float64
end

mutable struct Grass <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    fully_grown::Bool
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

To access the `Sheep`, `Wolf` and `Grass` types, simply call
``` julia
using Agents.Models: Sheep, Wolf, Grass
```
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
    space = GridSpace(dims, periodic = false)
    properties = Dict(:Δenergy_wolf => Δenergy_wolf, :Δenergy_sheep => Δenergy_sheep, :regrowth_time => regrowth_time, :sheep_reproduce => sheep_reproduce, :wolf_reproduce => wolf_reproduce)
    model =
        ABM(Union{Sheep,Wolf,Grass}, space, scheduler = by_type(true, true), warn = false, properties=properties)
    id = 0
    for _ in 1:n_sheep
        id += 1
        energy = rand(1:(Δenergy_sheep * 2)) - 1
        ## Note that we must instantiate agents before adding them in a mixed-ABM
        ## to confirm their type.
        sheep = Sheep(id, (0, 0), energy)
        add_agent!(sheep, model)
    end
    for _ in 1:n_wolves
        id += 1
        energy = rand(1:(Δenergy_wolf * 2)) - 1
        wolf = Wolf(id, (0, 0), energy)
        add_agent!(wolf, model)
    end
    for p in positions(model)
        id += 1
        fully_grown = rand(Bool)
        countdown = fully_grown ? regrowth_time : rand(1:regrowth_time) - 1
        grass = Grass(id, (0, 0), fully_grown, countdown)
        add_agent!(grass, p, model)
    end
    return model, predator_prey_agent_step!, dummystep
end

function predator_prey_agent_step!(sheep::Sheep, model)
    move!(sheep, model)
    sheep.energy -= 1
    agents = collect(agents_in_position(sheep.pos, model))
    dinner = filter!(x -> isa(x, Grass), agents)
    eat!(sheep, dinner, model)
    if sheep.energy < 0
        kill_agent!(sheep, model)
        return
    end
    if rand() <= model.sheep_reproduce
        reproduce!(sheep, model)
    end
end

function predator_prey_agent_step!(wolf::Wolf, model)
    move!(wolf, model)
    wolf.energy -= 1
    agents = collect(agents_in_position(wolf.pos, model))
    dinner = filter!(x -> isa(x, Sheep), agents)
    eat!(wolf, dinner, model)
    if wolf.energy < 0
        kill_agent!(wolf, model)
        return
    end
    if rand() <= model.wolf_reproduce
        reproduce!(wolf, model)
    end
end

function predator_prey_agent_step!(grass::Grass, model)
    if !grass.fully_grown
        if grass.countdown <= 0
            grass.fully_grown = true
            grass.countdown = model.regrowth_time
        else
            grass.countdown -= 1
        end
    end
end

function move!(agent, model)
    neighbors = nearby_positions(agent, model)
    position = rand(collect(neighbors))
    move_agent!(agent, position, model)
end

function eat!(sheep::Sheep, grass_array, model)
    isempty(grass_array) && return
    grass = grass_array[1]
    if grass.fully_grown
        sheep.energy += model.Δenergy_sheep
        grass.fully_grown = false
    end
end

function eat!(wolf::Wolf, sheep, model)
    if !isempty(sheep)
        dinner = rand(sheep)
        kill_agent!(dinner, model)
        wolf.energy += model.Δenergy_wolf
    end
end

function reproduce!(agent, model)
    agent.energy /= 2
    id = nextid(model)
    A = typeof(agent)
    offspring = A(id, agent.pos, agent.energy)
    add_agent_pos!(offspring, model)
    return
end

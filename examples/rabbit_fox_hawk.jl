using Agents, Agents.Pathfinding
using Random
using FileIO
using ImageMagick # hide

@agent Animal GridAgent{2} begin
    type::Symbol
    energy::Int
end

Rabbit(id, pos, energy) = Animal(id, pos, :rabbit, energy)
Fox(id, pos, energy) = Animal(id, pos, :fox, energy)
Hawk(id, pos, energy) = Animal(id, pos, :hawk, energy)

function initialize_model(
    heightmap_url,
    water_level = 60,
    grass_level = 110,
    mountain_level = 150;
    n_rabbits = 140,
    n_foxes = 80,
    n_hawks = 60,
    Δe_rabbit = 4,
    Δe_fox = 40,
    Δe_hawk = 40,
    rabbit_repr = 0.03,
    fox_repr = 0.04,
    hawk_repr = 0.04,
    rabbit_vision = 3,
    fox_vision = 5,
    hawk_vision = 7,
    regrowth_chance = 0.05,
    seed = 42,
)
    heightmap = floor.(Int, convert.(Float64, load(heightmap_url)) * 256)
    dims = size(heightmap)

    rng = MersenneTwister(seed)

    space = GridSpace(dims; periodic = false)
    land_walkmap = BitArray(map(x -> water_level < x < mountain_level, heightmap))
    air_walkmap = BitArray(map(x -> x < mountain_level, heightmap))
    grass = BitArray(
        rand(rng, dims...) .< ((grass_level .- heightmap) ./ (grass_level - water_level)),
    )
    properties = (
        landfinder = AStar(
            space;
            walkable = land_walkmap,
            cost_metric = HeightMap(heightmap, MaxDistance{2}()),
        ),
        airfinder = AStar(space; walkable = air_walkmap),
        Δe_rabbit = Δe_rabbit,
        Δe_fox = Δe_fox,
        Δe_hawk = Δe_hawk,
        rabbit_repr = rabbit_repr,
        fox_repr = fox_repr,
        hawk_repr = hawk_repr,
        rabbit_vision = rabbit_vision,
        fox_vision = fox_vision,
        hawk_vision = hawk_vision,
        grass = grass,
        regrowth_chance = regrowth_chance,
        water_level = water_level,
        grass_level = grass_level,
    )

    model = ABM(Animal, space; rng, properties)

    valid_positions = filter(x -> land_walkmap[x], CartesianIndices(land_walkmap))
    for _ in 1:n_rabbits
        add_agent_pos!(
            Rabbit(
                nextid(model),
                rand(model.rng, valid_positions),
                rand(model.rng, Δe_rabbit:2Δe_rabbit),
            ),
            model,
        )
    end
    for _ in 1:n_foxes
        add_agent_pos!(
            Fox(
                nextid(model),
                rand(model.rng, valid_positions),
                rand(model.rng, Δe_fox:2Δe_fox),
            ),
            model,
        )
    end

    for _ in 1:n_hawks
        add_agent_pos!(
            Hawk(
                nextid(model),
                rand(model.rng, valid_positions),
                rand(model.rng, Δe_hawk:2Δe_hawk),
            ),
            model,
        )
    end

    model
end

nearby_walkable(pos, model, pathfinder, r = 1) = filter(x -> pathfinder.walkable[x...] == 1, collect(nearby_positions(pos, model, r)))

function animal_step!(animal, model)
    if animal.type == :rabbit
        rabbit_step!(animal, model)
    elseif animal.type == :fox
        fox_step!(animal, model)
    else
        hawk_step!(animal, model)
    end
end

function rabbit_step!(rabbit, model)
    if model.grass[rabbit.pos...] == 1
        model.grass[rabbit.pos...] = 0
        rabbit.energy += model.Δe_rabbit
    end

    rabbit.energy -= 1

    if rabbit.energy <= 0
        kill_agent!(rabbit, model, model.landfinder)
        return
    end

    predators = [x.pos for x in nearby_agents(rabbit, model, model.rabbit_vision) if x.type == :fox || x.type == :hawk]

    walkable_neighbors = nearby_walkable(rabbit.pos, model, model.landfinder)

    if !isempty(predators)
        direction = (0, 0)
        for predator in predators
            away_direction = rabbit.pos .- predator
            direction = direction .+ away_direction ./ sum(away_direction .^ 2)
        end
        direction = direction ./ √sum(direction .^ 2)
        ideal_position = rabbit.pos .+ direction
        best = argmin(map(x -> sum((x .- ideal_position) .^ 2), walkable_neighbors))

        move_agent!(rabbit, walkable_neighbors[best], model)
        return
    end

    rand(model.rng) <= model.rabbit_repr && reproduce!(rabbit, model)

    if is_stationary(rabbit, model.landfinder)
        grass = [x for x in nearby_walkable(rabbit.pos, model, model.landfinder, model.rabbit_vision) if model.grass[x...] == 1]
        if isempty(grass)
            set_target!(rabbit, rand(model.rng, nearby_walkable(rabbit.pos, model, model.landfinder, model.rabbit_vision)), model.landfinder)
            return
        end
        set_target!(rabbit, rand(model.rng, grass), model.landfinder)
    end

    move_along_route!(rabbit, model, model.landfinder)
end

function fox_step!(fox, model)
    food = [x for x in nearby_agents(fox, model) if x.type == :rabbit]
    if !isempty(food)
        kill_agent!(rand(model.rng, food), model, model.landfinder)
        fox.energy += model.Δe_fox
    end

    fox.energy -= 1
    if fox.energy <= 0
        kill_agent!(fox, model, model.landfinder)
        return
    end

    rand(model.rng) <= model.fox_repr && reproduce!(fox, model)

    if is_stationary(fox, model.landfinder)
        prey = [ x for x in nearby_agents(fox, model, model.fox_vision) if x.type == :rabbit]
        if isempty(prey)
            set_target!(
                fox,
                rand(model.rng, nearby_walkable(fox.pos, model, model.landfinder, model.fox_vision)),
                model.landfinder,
            )
            return
        end
        set_best_target!(fox, map(x -> x.pos, prey), model.landfinder)
    end

    move_along_route!(fox, model, model.landfinder)
end

function hawk_step!(hawk, model)
    food = [x for x in nearby_agents(hawk, model) if x.type == :rabbit]
    if !isempty(food)
        kill_agent!(rand(model.rng, food), model, model.airfinder)
        hawk.energy += model.Δe_hawk
    end

    hawk.energy -= 1
    if hawk.energy <= 0
        kill_agent!(hawk, model, model.airfinder)
        return
    end

    rand(model.rng) <= model.hawk_repr && reproduce!(hawk, model)

    if is_stationary(hawk, model.airfinder)
        prey = [x for x in nearby_agents(hawk, model, model.hawk_vision) if x.type == :rabbit]
        if isempty(prey)
            set_target!(
                hawk,
                rand(model.rng, collect(nearby_walkable(hawk.pos, model, model.airfinder, model.hawk_vision))),
                model.airfinder,
            )
            return
        end

        set_best_target!(hawk, map(x -> x.pos, prey), model.airfinder)
    end

    move_along_route!(hawk, model, model.airfinder)
end

function reproduce!(agent, model)
    agent.energy = ceil(Int, agent.energy / 2)
    add_agent_pos!(
        Animal(
            nextid(model),
            agent.pos,
            agent.type,
            agent.energy,
        ),
        model,
    )
end

function model_step!(model)
    growable = view(model.grass, model.grass .== 0 .& model.water_level .< heightmap(model.landfinder) .<= model.grass_level)
    growable .= rand(model.rng, length(growable)) .< model.regrowth_chance
end

animalmarker(a) =
    if a.type == :rabbit
        :circle
    elseif a.type == :fox
        :rect
    else
        :utriangle
    end
animalcolor(a) =
    if a.type == :rabbit
        (:brown, 0.6)
    elseif a.type == :fox
        (:orange, 0.6)
    else
        (:blue, 0.6)
    end

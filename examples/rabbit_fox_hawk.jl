using Agents, Agents.Pathfinding
using Random
using FileIO
using ImageMagick # hide

@agent Animal GridAgent{3} begin
    type::Symbol
    energy::Int
end

Rabbit(id, pos, energy) = Animal(id, pos, :rabbit, energy)
Fox(id, pos, energy) = Animal(id, pos, :fox, energy)
Hawk(id, pos, energy) = Animal(id, pos, :hawk, energy)

function initialize_model(
    heightmap_url,
    water_level = 10,
    grass_level = 20,
    mountain_level = 35;
    n_rabbits = 120,
    n_foxes = 60,
    n_hawks = 60,
    Δe_rabbit = 4,
    Δe_fox = 40,
    Δe_hawk = 50,
    rabbit_repr = 0.03,
    fox_repr = 0.04,
    hawk_repr = 0.04,
    rabbit_vision = 3,
    fox_vision = 9,
    hawk_vision = 20,
    regrowth_chance = 0.01,
    seed = 42,
)
    heightmap = floor.(Int, convert.(Float64, load(heightmap_url)) * 39) .+ 1
    dims = (size(heightmap)..., 40)

    rng = MersenneTwister(seed)

    space = GridSpace(dims; periodic = false)
    land_walkmap = BitArray(falses(dims...))
    air_walkmap = BitArray(falses(dims...))
    for i in 1:dims[1], j in 1:dims[2]
        water_level < heightmap[i, j] < grass_level &&
            (land_walkmap[i, j, heightmap[i, j]+1] = true)
        heightmap[i, j] < mountain_level &&
            (air_walkmap[i, j, (heightmap[i, j]+1):end] .= true)
    end
    grass = BitArray(
        rand(rng, dims[1:2]...) .< ((grass_level .- heightmap) ./ (grass_level - water_level)),
    )
    properties = (
        landfinder = AStar(space; walkable = land_walkmap, cost_metric = DirectDistance{3}()),
        airfinder = AStar(space; walkable = air_walkmap, cost_metric = MaxDistance{3}()),
        Δe_rabbit = Δe_rabbit,
        Δe_fox = Δe_fox,
        Δe_hawk = Δe_hawk,
        rabbit_repr = rabbit_repr,
        fox_repr = fox_repr,
        hawk_repr = hawk_repr,
        rabbit_vision = rabbit_vision,
        fox_vision = fox_vision,
        hawk_vision = hawk_vision,
        heightmap = heightmap,
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

    valid_position =
        filter(x -> air_walkmap[x] && x[3] > water_level, CartesianIndices(air_walkmap))
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

nearby_walkable(pos, model, pathfinder, r = 1) =
    filter(x -> pathfinder.walkable[x...] == 1, collect(nearby_positions(pos, model, r)))

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
    if model.grass[rabbit.pos[1:2]...] == 1
        model.grass[rabbit.pos[1:2]...] = 0
        rabbit.energy += model.Δe_rabbit
    end

    rabbit.energy -= 1

    if rabbit.energy <= 0
        kill_agent!(rabbit, model, model.landfinder)
        return
    end

    predators = [
        x.pos for x in nearby_agents(rabbit, model, model.rabbit_vision) if
            x.type == :fox || x.type == :hawk
    ]

    walkable_neighbors = nearby_walkable(rabbit.pos, model, model.landfinder)

    if !isempty(predators)
        direction = (0, 0, 0)
        for predator in predators
            away_direction = (rabbit.pos .- predator) .* (1, 1, 0)
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
        grass = [
            x for
            x in nearby_walkable(rabbit.pos, model, model.landfinder, model.rabbit_vision) if
            model.grass[x[1:2]...] == 1
        ]
        if isempty(grass)
            set_target!(
                rabbit,
                rand(
                    model.rng,
                    nearby_walkable(rabbit.pos, model, model.landfinder, model.rabbit_vision),
                ),
                model.landfinder,
            )
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
        prey = [x for x in nearby_agents(fox, model, model.fox_vision) if x.type == :rabbit]
        if isempty(prey)
            set_target!(
                fox,
                rand(
                    model.rng,
                    nearby_walkable(fox.pos, model, model.landfinder, model.fox_vision),
                ),
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
        set_target!(hawk, hawk.pos .+ (0, 0, 3), model.airfinder)
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
                rand(
                    model.rng,
                    collect(
                        nearby_walkable(hawk.pos, model, model.airfinder, model.hawk_vision),
                    ),
                ),
                model.airfinder,
            )
        else
            set_best_target!(hawk, map(x -> x.pos, prey), model.airfinder)
        end
    end

    move_along_route!(hawk, model, model.airfinder)
end

function reproduce!(agent, model)
    agent.energy = ceil(Int, agent.energy / 2)
    add_agent_pos!(Animal(nextid(model), agent.pos, agent.type, agent.energy), model)
end

function model_step!(model)
    growable = view(
        model.grass,
        model.grass .== 0 .& model.water_level .< model.heightmap .<= model.grass_level,
    )
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
        :brown
    elseif a.type == :fox
        :orange
    else
        :blue
    end

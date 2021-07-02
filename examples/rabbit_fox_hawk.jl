using Agents, Agents.Pathfinding
using FileIO

@agent Animal GridAgent{2} begin
    type::Symbol
    energy::Int
end

Rabbit(id, pos, energy) = Animal(id, pos, :rabbit, energy)
Fox(id, pos, energy) = Animal(id, pos, :fox, energy)
Hawk(id, pos, energy) = Animal(id, pos, :hawk, energy)

function initialize_model(
    heightmap_url,
    water_level = 10,
    grass_level = 80,
    mountain_level = 120;
    n_rabbits = 120,
    n_foxes = 60,
    n_hawks = 60,
    dims = (25, 25),
    Δe_rabbit = 4,
    Δe_fox = 20,
    Δe_hawk = 40,
    rabbit_repr = 0.05,
    fox_repr = 0.04,
    hawk_repr = 0.04,
    rabbit_vision = 3,
    fox_vision = 5,
    hawk_vision = 7,
    regrowth_chance = 0.1,
    seed = 42,
)
    rng = MersenneTwister(seed)

    space = GridSpace(dims; periodic = false)
    heightmap = map(x -> x.r * 256, load(download(heightmap_url)))
    land_walkmap = BitArray(map(x -> water_level < x < mountain_level, heightmap))
    air_walkmap = BitArray(map(x -> x < mountain_level, heightmap))
    grass = BitArray(
        rand(rng, dims...) .< ((grass_level .- heightmap) ./ (grass_level - water_level)),
    )
    properties = (
        landfinder = AStar(
            space;
            walkmap = land_walkmap,
            cost_metric = HeightMap(heightmap, MaxDistance{2}()),
        ),
        airfinder = AStar(space; walkmap = air_walkmap),
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
    )

    model = ABM(Animal, space; rng, properties)

    valid_positions = map(x -> land_walkmap[x], CartesianIndices(land_walkmap))
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

    valid_positions = map(x -> heightmap[x] < mountain_level, CartesianIndices(heightmap))
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
    filter(x -> pathfinder.walkable[x], nearby_positions(pos, model, r))

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
    if model.grass[rabbit.pos...]
        model.grass[rabbit.pos...] = 0
        rabbit.energy += model.Δe_rabbit
    end

    rabbit.energy -= 1

    if rabbit.energy <= 0
        kill_agent!(rabbit, model, model.landfinder)
        return
    end

    predators = map(
        x -> x.pos,
        filter(x -> x.type in [:fox, :hawk], nearby_agent(rabbit, model, model.rabbit_vision)),
    )

    walkable_neighbors = nearby_walkable(pos, model, model.landfinder)

    if !isempty(predators)
        closest = minimum(map(x -> sum.((x - rabbit.pos) .^ 2), predators))
        best = argmin(map(x -> sum.((x .- closest)) .^ 2, walkable_neighbors))
        move_agent!(rabbit, walkable_neighbors[best], model)
        return
    end

    rand(model.rng) <= model.rabbit_repr && reproduce_rabbit!(rabbit, model)

    if is_stationary(rabbit, model, model.landfinder)
        grass = filter(
            x -> model.grass[x],
            nearby_positions(rabbit.pos, model, model.rabbit_vision),
        )
        if isempty(grass)
            move_agent!(rabbit, rand(model.rng, walkable_neighbors), model)
            return
        end
        set_best_target!(rabbit, grass, model.landfinder)
    end

    move_along_route!(rabbit, model, model.landfinder)
end

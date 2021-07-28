# # 3D Predator-prey
# ```@raw html
# <video width="auto" controls autoplay loop>
# <source src="../rabbit_fox_hawk.mp4" type="video/mp4">
# </video>
# ```
# This model is a variation on the [Predator-Prey](@ref) example. It uses a 3-dimensional
# [`GridSpace`](@ref), a realistic terrain for the agents, and pathfinding (with multiple
# pathfinders).
#
# Agents in this model are one of three species of animals: rabbits, foxes and hawks. Rabbits
# eat grass, and are hunted by foxes and hawks. While rabbits and foxes are restricted to
# walk on suitable portions of the map, hawks are capable of flight and can fly over a much
# larger region of the map.
#
# Similar to the [Predator-Prey](@ref) example, agent types are distinguished using a `type`
# field. Agents also have an additional `energy` field, which is consumed to move around and
# reproduce. Eating food (grass or rabbits) replenishes `energy` by a fixed amount.
using Agents, Agents.Pathfinding
using Random
using FileIO
using ImageMagick # hide

mutable struct Animal <: AbstractAgent
    id::Int
    pos::NTuple{3,Float64}
    type::Symbol ## one of :rabbit, :fox or :hawk
    energy::Float64
end

## Some utility functions to create specific types of agents, and find the norm of a vector
Rabbit(id, pos, energy) = Animal(id, pos, :rabbit, energy)
Fox(id, pos, energy) = Animal(id, pos, :fox, energy)
Hawk(id, pos, energy) = Animal(id, pos, :hawk, energy)
norm(vec) = √sum(vec .^ 2)

# The environment is generated from a heightmap: a 2D matrix, where each value denotes the
# height of the terrain at that point. We segregate the model into 4 regions based on the
# height:
# - Anything below `water_level` is waster and cannot be walked on
# - The region between `water_level` and `grass_level` is flatland, that can be walked on
# - The part of the map between `grass_level` and `mountain_level` is too high for animals to
#   walk over, but it can be flown over
# - The terrain above `mountain_level` is completely inaccessible
#
# Grass is the food source for rabbits. It can grow anywhere from `water_level` to `grass_level`.
# The spread of grass across the terrain is specified using a BitArray. A value of
# 1 at a location indicates the presence of grass there, which can be consumed when it is eaten
# by a rabbit. The probability of grass growing is proportional to how close it is to the water.
#
# The `initialize_model` function takes in the URL to our heightmap, the thresholds for the 4
# regions, and some additional parameters for the model. It then creates and returns a model
# with the specified heightmap and containing the specified number of rabbits, foxes and hawks.

function initialize_model(
    heightmap_url,
    water_level = 10,
    grass_level = 20,
    mountain_level = 35;
    n_rabbits = 160,  ## initial number of rabbits
    n_foxes = 30,  ## initial number of foxes
    n_hawks = 30,  ## initial number of hawks
    Δe_grass = 25,  ## energy gained from eating grass
    Δe_rabbit = 40,  ## energy gained from eating one rabbit
    rabbit_repr = 0.06,  ## probability for a rabbit to (asexually) reproduce at any step
    fox_repr = 0.03,  ## probability for a fox to (asexually) reproduce at any step
    hawk_repr = 0.02, ## probability for a hawk to (asexually) reproduce at any step
    rabbit_vision = 6,  ## how far rabbits can see grass and spot predators
    fox_vision = 12,  ## how far foxes can see rabbits to hunt
    hawk_vision = 24,  ## how far hawks can see rabbits to hunt
    rabbit_speed = 1.3, ## movement speed of rabbits
    fox_speed = 1.4,  ## movement speed of foxes
    hawk_speed = 1.5, ## movement speed of hawks
    regrowth_chance = 0.01,  ## probability that a patch of grass regrows at any step
    dt = 0.1,   ## discrete timestep each iteration of the model
    seed = 42,  ## seed for random number generator
)

    ## Download and load the heightmap. The grayscale value is converted to `Float64` and
    ## scaled from 1 to 40
    heightmap = floor.(Int, convert.(Float64, load(download(heightmap_url))) * 39) .+ 1
    ## The dimensions of the pathfinder is that of the heightmap
    dims = (size(heightmap)..., 40)
    ## Generate the RNG for the model
    rng = MersenneTwister(seed)

    space = ContinuousSpace((100., 100., 40.); periodic = false)

    ## The region of the map that is accessible to each type of animal (land-based or flying)
    ## is defined using `BitArrays`
    land_walkmap = BitArray(falses(dims...))
    air_walkmap = BitArray(falses(dims...))
    for i in 1:dims[1], j in 1:dims[2]
        ## land animals can only walk on top of the terrain between water_level and grass_level
        if water_level < heightmap[i, j] < grass_level
            land_walkmap[i, j, heightmap[i, j]+1] = true
        end
        ## air animals can fly at any height upto mountain_level
        if heightmap[i, j] < mountain_level
            air_walkmap[i, j, (heightmap[i, j]+1):mountain_level] .= true
        end
    end
    ## Generate an array of random numbers, and threshold it by the probability of grass growing
    ## at that location. Although this causes grass to grow below `water_level`, it is
    ## effectively ignored by `land_walkmap`
    grass = BitArray(
        rand(rng, dims[1:2]...) .< ((grass_level .- heightmap) ./ (grass_level - water_level)),
    )
    properties = (
        ## The pathfinder for rabbits and foxes
        landfinder = AStar(space, land_walkmap),
        ## The pathfinder for hawks
        airfinder = AStar(space, air_walkmap; cost_metric = MaxDistance{3}()),
        Δe_grass = Δe_grass,
        Δe_rabbit = Δe_rabbit,
        rabbit_repr = rabbit_repr,
        fox_repr = fox_repr,
        hawk_repr = hawk_repr,
        rabbit_vision = rabbit_vision,
        fox_vision = fox_vision,
        hawk_vision = hawk_vision,
        rabbit_speed = rabbit_speed,
        fox_speed = fox_speed,
        hawk_speed = hawk_speed,
        heightmap = heightmap,
        grass = grass,
        regrowth_chance = regrowth_chance,
        water_level = water_level,
        grass_level = grass_level,
        dt = dt,
    )

    model = ABM(Animal, space; rng, properties)

    ## Get a list of the valid places for rabbits and foxes to spawn
    valid_positions = filter(x -> land_walkmap[x], CartesianIndices(land_walkmap))
    ## Factor to convert walkmap index to position in space
    conversion_factor = size(space) ./ dims
    for _ in 1:n_rabbits
        add_agent_pos!(
            Rabbit(
                nextid(model),
                Tuple(rand(model.rng, valid_positions)) .* conversion_factor .- conversion_factor ./ 2.,
                rand(model.rng, Δe_grass:2Δe_grass),
            ),
            model,
        )
    end
    for _ in 1:n_foxes
        add_agent_pos!(
            Fox(
                nextid(model),
                Tuple(rand(model.rng, valid_positions)) .* conversion_factor .- conversion_factor ./ 2.,
                rand(model.rng, Δe_rabbit:2Δe_rabbit),
            ),
            model,
        )
    end

    ## Get a list of valid places for hawks to spawn
    valid_positions =
        filter(x -> air_walkmap[x] && heightmap[x[1], x[2]] > water_level, CartesianIndices(air_walkmap))
    for _ in 1:n_hawks
        add_agent_pos!(
            Hawk(
                nextid(model),
                Tuple(rand(model.rng, valid_positions)) .* conversion_factor .- conversion_factor ./ 2.,
                rand(model.rng, Δe_rabbit:2Δe_rabbit),
            ),
            model,
        )
    end

    model
end

to_heightmap_index(pos, model) =
    floor.(Int, pos[1:2] ./ size(model.space)[1:2] .* size(model.heightmap)) .+ 1

# The `animal_step!` function dispatches to the proper function depending on the type of agent.
# The stepping functions for each type of agent are similar: They lose one energy per step, and
# die if their energy ever reaches 0. They also have a random probability to reproduce at an
# iteration. Agents all move towards their food. In the case of rabbits, they also move away
# from any nearby predators.

function animal_step!(animal, model)
    if animal.type == :rabbit
        rabbit_step!(animal, model)
    elseif animal.type == :fox
        fox_step!(animal, model)
    else
        hawk_step!(animal, model)
    end
end

# Rabbits eat grass at their position, if it exists. If they see a predator, they run away.
# The direction in which they flee is dependent on all predators in their vision, with closer
# ones contributing more to the chosen direction. If there are no predators to flee from,
# rabbits walk to a random patch of grass within their vision.

function rabbit_step!(rabbit, model)
    ## Eat grass at this position, if any
    if model.grass[to_heightmap_index(rabbit.pos, model)...] == 1
        model.grass[to_heightmap_index(rabbit.pos, model)...] = 0
        rabbit.energy += model.Δe_grass
    end

    ## Energy cost per step scales with timestep. All animals die if their energy reaches 0
    rabbit.energy -= model.dt
    if rabbit.energy <= 0
        kill_agent!(rabbit, model, model.landfinder)
        return
    end

    ## Get a list of positions of all nearby predators
    predators = [
        x.pos for x in nearby_agents(rabbit, model, model.rabbit_vision) if
            x.type == :fox || x.type == :hawk
    ]
    if !isempty(predators) && is_stationary(rabbit, model.landfinder)
        ## If there are predators to run from
        direction = (0., 0., 0.)
        for predator in predators
            ## Get the direction away from the predator
            away_direction = (rabbit.pos .- predator)
            all(away_direction .≈ 0.) && continue
            ## Add this to the overall direction, scaling inversely with distance
            direction = direction .+ away_direction ./ norm(away_direction) ^ 2
        end
        if !all(direction .≈ 0.)
            ## Normalize the resultant direction, and get the ideal position to move it
            direction = direction ./ norm(direction)
            ideal_position = rabbit.pos .+ direction

            ideal_position = random_walkable(ideal_position, model, model.landfinder)

            set_target!(rabbit, ideal_position, model.landfinder)
        end
    end

    ## Reproduce with a random probability
    rand(model.rng) <= model.rabbit_repr * model.dt && reproduce!(rabbit, model)

    ## If the rabbit isn't already moving somewhere
    if is_stationary(rabbit, model.landfinder)
        set_target!(
            rabbit,
            random_walkable(rabbit.pos, model, model.landfinder, model.rabbit_vision),
            model.landfinder
        )
    end

    move_along_route!(rabbit, model, model.landfinder, model.rabbit_speed, model.dt)
end

# Foxes hunt for rabbits, and eat rabbits within a unit radius of its position.

function fox_step!(fox, model)
    ## Look for nearby rabbits that can be eaten
    food = [x for x in nearby_agents(fox, model) if x.type == :rabbit]
    if !isempty(food)
        kill_agent!(rand(model.rng, food), model, model.landfinder)
        fox.energy += model.Δe_rabbit
    end

    ## One unit of energy is consumed every step
    fox.energy -= model.dt
    if fox.energy <= 0
        kill_agent!(fox, model, model.landfinder)
        return
    end

    ## Random chance to reproduce every step
    rand(model.rng) <= model.fox_repr * model.dt && reproduce!(fox, model)

    ## This movement logic is similar to that of rabbits looking for grass, except foxes
    ## look for rabbits
    if is_stationary(fox, model.landfinder)
        prey = [x for x in nearby_agents(fox, model, model.fox_vision) if x.type == :rabbit]
        if isempty(prey)
            set_target!(
                fox,
                random_walkable(fox.pos, model, model.landfinder, model.fox_vision),
                model.landfinder,
            )
            return
        end
        ## Instead of moving toward a random rabbit, move toward the closest one
        set_target!(fox, rand(model.rng, map(x -> x.pos, prey)), model.landfinder)
    end

    move_along_route!(fox, model, model.landfinder, model.fox_speed, model.dt)
end

# Hawks function similarly to foxes, except they can also fly. They dive down for prey and
# fly back up after eating it.

function hawk_step!(hawk, model)
    ## Look for rabbits nearby
    food = [x for x in nearby_agents(hawk, model) if x.type == :rabbit]
    if !isempty(food)
        ## Eat (kill) the rabbit
        kill_agent!(rand(model.rng, food), model, model.airfinder)
        hawk.energy += model.Δe_rabbit
        ## Fly back up
        set_target!(hawk, hawk.pos .+ (0, 0, 3), model.airfinder)
    end

    ## The rest of the stepping function is similar to that of foxes, except hawks use a
    ## different pathfinder
    hawk.energy -= model.dt
    if hawk.energy <= 0
        kill_agent!(hawk, model, model.airfinder)
        return
    end

    rand(model.rng) <= model.hawk_repr * model.dt && reproduce!(hawk, model)

    if is_stationary(hawk, model.airfinder)
        prey = [x for x in nearby_agents(hawk, model, model.hawk_vision) if x.type == :rabbit]
        if isempty(prey)
            set_target!(
                hawk,
                random_walkable(hawk.pos, model, model.airfinder, model.hawk_vision),
                model.airfinder,
            )
        else
            set_target!(hawk, rand(model.rng, map(x -> x.pos, prey)), model.airfinder)
        end
    end

    move_along_route!(hawk, model, model.airfinder, model.hawk_speed, model.dt)
end

# This function is called when an animal reproduces. The animal loses half its energy, and
# a copy of it is created and added to the model.

function reproduce!(animal, model)
    animal.energy = ceil(Int, animal.energy / 2)
    add_agent_pos!(Animal(nextid(model), animal.pos, animal.type, animal.energy), model)
end

# The model stepping function simulates the growth of grass

function model_step!(model)
    ## To prevent copying of data, obtain a view of the part of the grass matrix that
    ## doesn't have any grass, and grass can grow there
    growable = view(
        model.grass,
        model.grass .== 0 .& model.water_level .< model.heightmap .<= model.grass_level,
    )
    ## Grass regrows with a random probability
    growable .= rand(model.rng, length(growable)) .< model.regrowth_chance
end

# ## Visualization
#
# The agents are color-coded according to their `type`, to make them easily identifiable in
# the visualization.

using InteractiveDynamics
using GLMakie
GLMakie.activate!() # hide

animalcolor(a) =
    if a.type == :rabbit
        :brown
    elseif a.type == :fox
        :orange
    else
        :blue
    end

# We use `surface!` to plot the terrain as a mesh, and colour it using the `:terrain`
# colormap. `zlims!` overrides the limits set by `InteractiveDynamics` to ensure the
# terrain surface isn't skewed by the dimensions of the model.
function static_preplot!(ax, model)
    zlims!(ax, (0, 164))
    surface!(ax, (100/205):(100/205):100, (100/205):(100/205):100, model.heightmap; colormap = :terrain)
end

## The sample heightmap used for this model
heightmap_url =
    "https://raw.githubusercontent.com/JuliaDynamics/" *
    "JuliaDynamics/master/videos/agents/rabbit_fox_hawk_heightmap.png"
model = initialize_model(heightmap_url)

abm_video(
    "rabbit_fox_hawk.mp4",
    model,
    animal_step!,
    model_step!;
    resolution = (700, 700),
    frames = 300,
    framerate = 30,
    ac = animalcolor,
    as = 1.0,
    static_preplot!
)

nothing # hide
# ```@raw html
# <video width="auto" controls autoplay loop>
# <source src="../rabbit_fox_hawk.mp4" type="video/mp4">
# </video>
# ```

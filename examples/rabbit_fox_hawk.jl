# # 3D Mixed-Agent Ecosystem with Pathfinding
# ```@raw html
# <video width="100%" height="auto" controls autoplay loop>
# <source src="https://raw.githubusercontent.com/JuliaDynamics/JuliaDynamics/master/videos/agents/rabbit_fox_hawk.mp4?raw=true" type="video/mp4">
# </video>
# ```

# This model is much more advanced version of the [Predator-prey dynamics](@ref) example.
# It uses a 3-dimensional
# [`ContinuousSpace`](@ref), a realistic terrain for the agents, and pathfinding (with multiple
# pathfinders). It should be considered an advanced example for showcasing pathfinding.
#
# Agents in this model are one of three species of animals: rabbits, foxes and hawks. Rabbits
# eat grass, and are hunted by foxes and hawks. While rabbits and foxes are restricted to
# walk on suitable portions of the map, hawks are capable of flight and can fly over a much
# larger region of the map.
#
# Because agents share all their properties, to optimize performance
# agent types are distinguished using a
# `type` field. Agents also have an additional `energy` field, which is consumed to move around
# and reproduce. Eating food (grass or rabbits) replenishes `energy` by a fixed amount.
using Agents, Agents.Pathfinding
using Random
import ImageMagick
using FileIO: load

@compact struct Animal(ContinuousAgent{3,Float64})
    @agent struct Rabbit
        energy::Float64
    end
    @agent struct Fox
        energy::Float64
    end
    @agent struct Hawk
        energy::Float64
    end
end

# A utility function to find the euclidean norm of a Vector
eunorm(vec) = √sum(vec .^ 2)
const v0 = (0.0, 0.0, 0.0) # we don't use the velocity field here

# The environment is generated from a heightmap: a 2D matrix, where each value denotes the
# height of the terrain at that point. We segregate the model into 4 regions based on the
# height:
# - Anything below `water_level` is water and cannot be walked on
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
    heightmap_url =
    "https://raw.githubusercontent.com/JuliaDynamics/" *
    "JuliaDynamics/master/videos/agents/rabbit_fox_hawk_heightmap.png",
    water_level = 8,
    grass_level = 20,
    mountain_level = 35;
    n_rabbits = 160,  ## initial number of rabbits
    n_foxes = 30,  ## initial number of foxes
    n_hawks = 30,  ## initial number of hawks
    Δe_grass = 25,  ## energy gained from eating grass
    Δe_rabbit = 30,  ## energy gained from eating one rabbit
    rabbit_repr = 0.06,  ## probability for a rabbit to (asexually) reproduce at any step
    fox_repr = 0.03,  ## probability for a fox to (asexually) reproduce at any step
    hawk_repr = 0.02, ## probability for a hawk to (asexually) reproduce at any step
    rabbit_vision = 6,  ## how far rabbits can see grass and spot predators
    fox_vision = 10,  ## how far foxes can see rabbits to hunt
    hawk_vision = 15,  ## how far hawks can see rabbits to hunt
    rabbit_speed = 1.3, ## movement speed of rabbits
    fox_speed = 1.1,  ## movement speed of foxes
    hawk_speed = 1.2, ## movement speed of hawks
    regrowth_chance = 0.03,  ## probability that a patch of grass regrows at any step
    dt = 0.1,   ## discrete timestep each iteration of the model
    seed = 42,  ## seed for random number generator
)

    ## Download and load the heightmap. The grayscale value is converted to `Float64` and
    ## scaled from 1 to 40
    heightmap = floor.(Int, convert.(Float64, load(download(heightmap_url))) * 39) .+ 1
    ## The x and y dimensions of the pathfinder are that of the heightmap
    dims = (size(heightmap)..., 50)
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

    ## Generate the RNG for the model
    rng = MersenneTwister(seed)

    ## Note that the dimensions of the space do not have to correspond to the dimensions
    ## of the pathfinder. Discretisation is handled by the pathfinding methods
    space = ContinuousSpace((100., 100., 50.); periodic = false)

    ## Generate an array of random numbers, and threshold it by the probability of grass growing
    ## at that location. Although this causes grass to grow below `water_level`, it is
    ## effectively ignored by `land_walkmap`
    grass = BitArray(
        rand(rng, dims[1:2]...) .< ((grass_level .- heightmap) ./ (grass_level - water_level)),
    )
    properties = (
        ## The pathfinder for rabbits and foxes
        landfinder = AStar(space; walkmap = land_walkmap),
        ## The pathfinder for hawks
        airfinder = AStar(space; walkmap = air_walkmap, cost_metric = MaxDistance{3}()),
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

    model = StandardABM(Animal, space; agent_step! = animal_step!, 
                        model_step! = model_step!, rng, properties)

    ## spawn each animal at a random walkable position according to its pathfinder
    for _ in 1:n_rabbits
        pos = random_walkable(model, model.landfinder)
        add_agent!(pos, Rabbit, model, v0, rand(abmrng(model), Δe_grass:2Δe_grass))
    end
    for _ in 1:n_foxes
        pos = random_walkable(model, model.landfinder)
        add_agent!(pos, Rabbit, model, v0, rand(abmrng(model), Δe_rabbit:2Δe_rabbit))
    end
    for _ in 1:n_hawks
        pos = random_walkable(model, model.airfinder)
        add_agent!(pos, Hawk, model, v0, rand(abmrng(model), Δe_rabbit:2Δe_rabbit))
    end
    return model
end

# ## Stepping functions

# The `animal_step!` function dispatches to the proper function depending on the type of agent.
# The stepping functions for each type of agent are similar: They lose energy per step, and
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
# rabbits walk around randomly.

function rabbit_step!(rabbit, model)
    ## Eat grass at this position, if any
    if get_spatial_property(rabbit.pos, model.grass, model) == 1
        model.grass[get_spatial_index(rabbit.pos, model.grass, model)] = 0
        rabbit.energy += model.Δe_grass
    end

    ## The energy cost at each step corresponds to the amount of time that has passed
    ## since the last step
    rabbit.energy -= model.dt
    ## All animals die if their energy reaches 0
    if rabbit.energy <= 0
        remove_agent!(rabbit, model, model.landfinder)
        return
    end

    ## Get a list of positions of all nearby predators
    predators = [
        x.pos for x in nearby_agents(rabbit, model, model.rabbit_vision) if
            x.type == :fox || x.type == :hawk
            ]
    ## If the rabbit sees a predator and isn't already moving somewhere
    if !isempty(predators) && is_stationary(rabbit, model.landfinder)
        ## Try and get an ideal direction away from predators
        direction = (0., 0., 0.)
        for predator in predators
            ## Get the direction away from the predator
            away_direction = (rabbit.pos .- predator)
            ## In case there is already a predator at our location, moving anywhere is
            ## moving away from it, so it doesn't contribute to `direction`
            all(away_direction .≈ 0.) && continue
            ## Add this to the overall direction, scaling inversely with distance.
            ## As a result, closer predators contribute more to the direction to move in
            direction = direction .+ away_direction ./ eunorm(away_direction) ^ 2
        end
        ## If the only predator is right on top of the rabbit
        if all(direction .≈ 0.)
            ## Move anywhere
            chosen_position = random_walkable(rabbit.pos, model, model.landfinder, model.rabbit_vision)
        else
            ## Normalize the resultant direction, and get the ideal position to move it
            direction = direction ./ eunorm(direction)
            ## Move to a random position in the general direction of away from predators
            position = rabbit.pos .+ direction .* (model.rabbit_vision / 2.)
            chosen_position = random_walkable(position, model, model.landfinder, model.rabbit_vision / 2.)
        end
        plan_route!(rabbit, chosen_position, model.landfinder)
    end

    ## Reproduce with a random probability, scaling according to the time passed each
    ## step
    rand(abmrng(model)) <= model.rabbit_repr * model.dt && reproduce!(rabbit, model)

    ## If the rabbit isn't already moving somewhere, move to a random spot
    if is_stationary(rabbit, model.landfinder)
        plan_route!(
            rabbit,
            random_walkable(rabbit.pos, model, model.landfinder, model.rabbit_vision),
            model.landfinder
        )
    end

    ## Move along the route planned above
    move_along_route!(rabbit, model, model.landfinder, model.rabbit_speed, model.dt)
end

# Foxes hunt for rabbits, and eat rabbits within a unit radius of its position.

function fox_step!(fox, model)
    ## Look for nearby rabbits that can be eaten
    food = [x for x in nearby_agents(fox, model) if x.type == :rabbit]
    if !isempty(food)
        remove_agent!(rand(abmrng(model), food), model, model.landfinder)
        fox.energy += model.Δe_rabbit
    end


    ## The energy cost at each step corresponds to the amount of time that has passed
    ## since the last step
    fox.energy -= model.dt
    ## All animals die once their energy reaches 0
    if fox.energy <= 0
        remove_agent!(fox, model, model.landfinder)
        return
    end

    ## Random chance to reproduce every step
    rand(abmrng(model)) <= model.fox_repr * model.dt && reproduce!(fox, model)

    ## If the fox isn't already moving somewhere
    if is_stationary(fox, model.landfinder)
        ## Look for any nearby rabbits
        prey = [x for x in nearby_agents(fox, model, model.fox_vision) if x.type == :rabbit]
        if isempty(prey)
            ## Move anywhere if no rabbits were found
            plan_route!(
                fox,
                random_walkable(fox.pos, model, model.landfinder, model.fox_vision),
                model.landfinder,
            )
        else
            ## Move toward a random rabbit
            plan_route!(fox, rand(abmrng(model), map(x -> x.pos, prey)), model.landfinder)
        end
    end

    move_along_route!(fox, model, model.landfinder, model.fox_speed, model.dt)
end

# Hawks function similarly to foxes, except they can also fly. They dive down for prey and
# fly back up after eating it.

function hawk_step!(hawk, model)
    ## Look for rabbits nearby
    food = [x for x in nearby_agents(hawk, model) if x.type == :rabbit]
    if !isempty(food)
        ## Eat (remove) the rabbit
        remove_agent!(rand(abmrng(model), food), model, model.airfinder)
        hawk.energy += model.Δe_rabbit
        ## Fly back up
        plan_route!(hawk, hawk.pos .+ (0., 0., 7.), model.airfinder)
    end

    ## The rest of the stepping function is similar to that of foxes, except hawks use a
    ## different pathfinder
    hawk.energy -= model.dt
    if hawk.energy <= 0
        remove_agent!(hawk, model, model.airfinder)
        return
    end

    rand(abmrng(model)) <= model.hawk_repr * model.dt && reproduce!(hawk, model)

    if is_stationary(hawk, model.airfinder)
        prey = [x for x in nearby_agents(hawk, model, model.hawk_vision) if x.type == :rabbit]
        if isempty(prey)
            plan_route!(
                hawk,
                random_walkable(hawk.pos, model, model.airfinder, model.hawk_vision),
                model.airfinder,
            )
        else
            plan_route!(hawk, rand(abmrng(model), map(x -> x.pos, prey)), model.airfinder)
        end
    end

    move_along_route!(hawk, model, model.airfinder, model.hawk_speed, model.dt)
end

# This function is called when an animal reproduces. The animal loses half its energy, and
# a copy of it is created and added to the model.

function reproduce!(animal, model)
    animal.energy = Float64(ceil(Int, animal.energy / 2))
    add_agent!(animal.pos, Animal, model, v0, animal.type, animal.energy)
end

# The model stepping function simulates the growth of grass

function model_step!(model)
    ## To prevent copying of data, obtain a view of the part of the grass matrix that
    ## doesn't have any grass, and grass can grow there
    growable = view(
        model.grass,
        model.grass .== 0 .& model.water_level .< model.heightmap .<= model.grass_level,
    )
    ## Grass regrows with a random probability, scaling with the amount of time passing
    ## each step of the model
    growable .= rand(abmrng(model), length(growable)) .< model.regrowth_chance * model.dt
end

# Passing in a sample heightmap to the `initialize_model` function we created returns the generated
# model.
model = initialize_model()

# ## Visualization
# Now we use `Makie` to create a visualization of the model running in 3D space
#
# The agents are color-coded according to their `type`, to make them easily identifiable in
# the visualization.

# ```julia
#
# using GLMakie # CairoMakie doesn't do 3D plots well
# ```

function animalcolor(a)
    if a.type == :rabbit
        :brown
    elseif a.type == :fox
        :orange
    else
        :blue
    end
end

# We use `surface!` to plot the terrain as a mesh, and colour it using the `:terrain`
# colormap. Since the heightmap dimensions don't correspond to the dimensions of the space,
# we explicitly provide ranges to specify where the heightmap should be plotted.
function static_preplot!(ax, model)
    surface!(
        ax,
        (100/205):(100/205):100,
        (100/205):(100/205):100,
        model.heightmap;
        colormap = :terrain
    )
end

# ```juia
# abmvideo(
#     "rabbit_fox_hawk.mp4",
#     model;
#     figure = (resolution = (800, 700),),
#     frames = 300,
#     framerate = 15,
#     ac = animalcolor,
#     as = 1.0,
#     static_preplot!,
#     title = "Rabbit Fox Hawk with pathfinding"
# )
# ```

# ```@raw html
# <video width="100%" height="auto" controls autoplay loop>
# <source src="https://raw.githubusercontent.com/JuliaDynamics/JuliaDynamics/master/videos/agents/rabbit_fox_hawk.mp4?raw=true" type="video/mp4">
# </video>
# ```

# # [Zombie Outbreak in an Open Street Map City](@id osm_example)
# ```@raw html
# <video width="auto" controls autoplay loop>
# <source src="../outbreak.mp4" type="video/mp4">
# </video>
# ```
#
# This model showcases an ABM running on a map, using [`OpenStreetMapSpace`](@ref).
# To access this functionality you need to load the `LightOSM` package.
#
# ## Constructing the end of days
using Agents
using Random
using LightOSM # required for this functionality

# We'll simulate a zombie outbreak in a city. To do so, we start with an agent which
# satisfies the [`OpenStreetMapSpace`](@ref) conditions of having a `pos`ition of type
# `Tuple{Int,Int,Float64}`. For simplicity though we shall build this with the [`@agent`](@ref)
# macro.

@agent struct Zombie(OSMAgent)
    infected::Bool
    speed::Float64
end

# To be explicit, this macro builds the following type:
# ```julia
# mutable struct Zombie <: AbstractAgent
#     id::Int
#     pos::Tuple{Int,Int,Float64}
#     infected::Bool
#     speed::Float64
# end
# ```
# where a tuple `(i, j, x)::Tuple{Int,Int,Float64}` means a position
# on the road between nodes `i, j` of the map, having progressed `x` distance along the road.

# The model constructor we build consists of a map, and 100 agents scattered randomly
# around it. They have their own agenda and need to travel to some new destination.
# Unfortunately one of the population has turned and will begin infecting anyone who
# comes close.

function initialise_zombies(; seed = 1234)
    map_path = OSM.test_map()
    properties = Dict(:dt => 1 / 60)
    model = StandardABM(
        Zombie,
        OpenStreetMapSpace(map_path);
        agent_step! = zombie_step!,
        properties = properties,
        rng = Random.MersenneTwister(seed)
    )

    for id in 1:100
        start = random_position(model) # At an intersection
        speed = rand(abmrng(model)) * 5.0 + 2.0 # Random speed from 2-7kmph
        human = add_agent!(start, Zombie, model, false, speed)
        OSM.plan_random_route!(human, model; limit = 50) # try 50 times to find a random route
    end
    ## We'll add patient zero at a specific (longitude, latitude)
    start = OSM.nearest_road((9.9351811, 51.5328328), model)
    finish = OSM.nearest_node((9.945125635913511, 51.530876112711745), model)

    speed = rand(abmrng(model)) * 5.0 + 2.0 # Random speed from 2-7kmph
    zombie = add_agent!(start, model, true, speed)
    OSM.plan_route!(zombie, finish, model)
    ## This function call creates & adds an agent, see `add_agent!`
    return model
end

# In our model, zombies are seemingly oblivious to their state, since they keep going about their
# business, but start eating people along the way. Perhaps they can finally express their distaste
# for city commuting.

function zombie_step!(agent, model)
    ## Each agent will progress along their route for a fixed amount of time per step.
    ## We keep track of distance left to move this step, in case the agent reaches its
    ## destination early.
    distance_left = OSM.move_along_route!(agent, model, agent.speed * model.dt)

    ## When stationary, give the agent a 10% chance of going somewhere else
    if OSM.is_stationary(agent, model) && rand(abmrng(model)) < 0.1
        OSM.plan_random_route!(agent, model; limit = 50)
        ## Start on new route, moving the remaining distance
        OSM.move_along_route!(agent, model, distance_left)
    end

    ## Agents will be infected if they get too close (within 10m) to a zombie.
    if agent.infected
        map(i -> model[i].infected = true, nearby_ids(agent, model, 0.01))
    end
    return
end

# ## Visualising the fall of humanity

# Plotting with Open Street Maps works right out of the box, provided that you have
# loaded the OSMMakie.jl package (besides any Makie plotting backend such as CairoMakie.jl.).
# In this case, the underlying open street map is plotted below the agent scatterplot.

using CairoMakie, OSMMakie
zombie_color(agent) = agent.infected ? :green : :black
zombie_size(agent) = agent.infected ? 14 : 10
zombies = initialise_zombies()

abmvideo(
    "outbreak.mp4", zombies;
    title = "Zombie outbreak", framerate = 15, frames = 200,
    agentsplotkwargs = (strokewidth = 1, strokecolor = :grey),
    agent_color = zombie_color, agent_size = zombie_size,
)

# ```@raw html
# <video width="auto" controls autoplay loop>
# <source src="../outbreak.mp4" type="video/mp4">
# </video>
# ```

# ## [Realistic simulation: Ride hailing in Chicago](@id anna_cobb)

# This zombie model is a simple, self-contained example to teach you the basics
# of using Open Street Map in Agents.jl. From here, the sky is the limit!
# For example, Anna Cobb et al., simulated the whole of Chicago to study
# racial imbalances in ride hailing (Uber, Lyft, ...), which resulted in a
# publication in [PNAS](https://www.pnas.org/doi/10.1073/pnas.2408936121).
# Here is an example of one of Anna's simulations:

# [Anna Cobb's Chicago simulation](../../anna_cobb_chicago.gif)

# Agents.jl allows doing such simulations with ease! Much easier than
# alternatives! In the author's own words:
# > "Using a pre-made model in MATSim nearly killed me.
# > Using a from-scratch model written in Julia with Agents.jl
# > led me to greatness.

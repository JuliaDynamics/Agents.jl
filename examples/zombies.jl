# # Zombie Outbreak
# ```@raw html
# <video width="auto" controls autoplay loop>
# <source src="https://raw.githubusercontent.com/JuliaDynamics/JuliaDynamics/master/videos/agents/zombies.mp4?raw=true" type="video/mp4">
# </video>
# ```
#
# This model showcases an ABM running on a map, using [`OpenStreetMapSpace`](@ref).
#
# ## Constructing the end of days
using Agents

# We'll simulate a zombie outbreak in a city. To do so, we start with an agent which
# satisfies the OSMSpace conditions of having a `pos`ition of type
# `Tuple{Int,Int,Float64}`. For simplicity though we shall build this with the [`@agent`](@ref)
# macro.

@agent Zombie OSMAgent begin
    infected::Bool
end

# To be explicit, this macro builds the following type:
# ```julia
# mutable struct Zombie <: AbstractAgent
#     id::Int
#     pos::Tuple{Int,Int,Float64}
#     infected::Bool
# end
# ```
# where a tuple `(i, j, x)::Tuple{Int,Int,Float64}` means a position
# on the road between nodes `i, j` of the map, having progressed `x` distance along the road.

# The model constructor we build consists of a map, and 100 agents scattered randomly
# around it. They have their own agenda and need to travel to some new destination.
# Unfortunately one of the population has turned and will begin infecting anyone who
# comes close.

function initialise(; seed = 1234)
    map_path = OSM.test_map()
    model = ABM(Zombie, OpenStreetMapSpace(map_path); rng = Random.MersenneTwister(seed))
    model = ABM(Zombie, OpenStreetMapSpace(map_path))

    for id in 1:100
        start = random_position(model) # At an intersection
        human = Zombie(id, start, false)
        add_agent_pos!(human, model)
        OSM.random_route!(human, model; limit = 50) # try 50 times to find a random route
    end
    ## We'll add patient zero at a specific (latitude, longitude)
    start = OSM.road((51.5328328, 9.9351811), model)
    finish = OSM.intersection((51.530876112711745, 9.945125635913511), model)
    zombie = add_agent!(start, model, true)
    plan_route!(zombie, finish, model)
    ## This function call creates & adds an agent, see `add_agent!`
    return model
end

# In our model, zombies are seemingly oblivious to their state, since they keep going about their
# business, but start eating people along the way. Perhaps they can finally express their distaste
# for city commuting.

function agent_step!(agent, model)
    ## Each agent will progress slightly along their route
    move_along_route!(agent, model, 0.005)

    if is_stationary(agent, model) && rand(model.rng) < 0.1
        ## When stationary, give the agent a 10% chance of going somewhere else
        OSM.random_route!(agent, model; limit = 50)
        ## Start on new route
        move_along_route!(agent, model, 0.0001)
    end

    if agent.infected
        ## Agents will be infected if they get too close to a zombie.
        map(i -> model[i].infected = true, nearby_ids(agent, model, 0.0003))
    end
    return
end

# ## Visualising the fall of humanity
#
# Plotting this space in a seamless manner is a work in progress. For now we
# use [OSMMakie.jl](https://github.com/fbanning/OSMMakie.jl) and
# a custom routine.

# using OSMMakie
using CairoMakie
ac(agent) = agent.infected ? :green : :black
as(agent) = agent.infected ? 6 : 5

model = initialise()

# fig, ax, plot = osmplot(model.space.map)
ids = model.scheduler(model)
colors = Node([ac(model[i]) for i in ids])
sizes = Node([as(model[i]) for i in ids])
marker = :circle
pos = Node(Point2f[OSM.latlon(model[i].pos, model) for i in ids])
fig, _= scatter(pos; color = colors, size = sizes, marker)

record(fig, "outbreak.mp4", 1:200; framerate = 15) do i
    Agents.step!(model, agent_step!, 1)
    ids = model.scheduler(model)
    colors[] = [ac(model[i]) for i in ids]
    sizes[] = [as(model[i]) for i in ids]
    pos[] = Point2f[OSM.latlon(model[i].pos, model) for i in ids]
end
# ```@raw html
# <video width="auto" controls autoplay loop>
# <source src="../outbreak.mp4" type="video/mp4">
# </video>
# ```

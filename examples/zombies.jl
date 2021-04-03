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
# `Tuple{Int,Int,Float64}`, a `route` vector and a `destination` with the same type as
# `pos`. For simplicity though we shall build this with the [`@agent`](@ref) macro.

@agent Zombie OSMAgent begin
    infected::Bool
end

# To be explicit, this macro builds the following type:
# ```julia
# mutable sturct Zombie <: AbstractAgent
#     id::Int
#     pos::Tuple{Int,Int,Float64}
#     route::Vector{Int}
#     destination::Tuple{Int,Int,Float64}
#     infected::Bool
# end
# ```
# where a tuple `(i, j, x)::Tuple{Int,Int,Float64}` means a position
# on the road between nodes `i, j` of the map, having progressed `x` meters along the road.

# The model constructor we build consists of a map, and 100 agents scattered randomly
# around it. They have their own agenda and need to travel to some new destination.
# Unfortunately one of the population has turned and will begin infecting anyone who
# comes close.

function initialise(; map_path = TEST_MAP)
    model = ABM(Zombie, OpenStreetMapSpace(map_path))

    for id in 1:100
        start = random_position(model) # At an intersection
        finish = osm_random_road_position(model) # Somewhere on a road
        route = osm_plan_route(start, finish, model)
        human = Zombie(id, start, route, finish, false)
        add_agent_pos!(human, model)
    end
    ## We'll add patient zero at a specific (latitude, longitude)
    start = osm_road((39.52320181536525, -119.78917553184259), model)
    finish = osm_intersection((39.510773, -119.75916700000002), model)
    route = osm_plan_route(start, finish, model)
    ## This function call creates & adds an agent, see `add_agent!`
    zombie = add_agent!(start, model, route, finish, true)
    return model
end

# In our model, zombies are seemingly oblivious to their state, since they keep going about their
# business, but start eating people along the way. Perhaps they can finally express their distaste
# for city commuting.

function agent_step!(agent, model)
    ## Each agent will progress 25 meters along their route
    move_agent!(agent, model, 25)

    if osm_is_stationary(agent) && rand(model.rng) < 0.1
        ## When stationary, give the agent a 10% chance of going somewhere else
        osm_random_route!(agent, model)
        ## Start on new route
        move_agent!(agent, model, 25)
    end

    if agent.infected
        ## Agents will be infected if they get within 50 meters of a zombie.
        map(i -> model[i].infected = true, nearby_ids(agent, model, 50))
    end
end

# ## Visualising the fall of humanity
#
# Plotting this space in a seamless manner is a work in progress. For now we
# use [OpenStreetMapXPlot](https://github.com/pszufe/OpenStreetMapXPlot.jl) and
# a custom routine.

# ```julia
# using OpenStreetMapXPlot
# using Plots
# gr()
# ```

ac(agent) = agent.infected ? :green : :black
as(agent) = agent.infected ? 6 : 5

function plotagents(model)
    ids = model.scheduler(model)
    colors = [ac(model[i]) for i in ids]
    sizes = [as(model[i]) for i in ids]
    markers = :circle
    pos = [osm_map_coordinates(model[i], model) for i in ids]

    scatter!(
        pos;
        markercolor = colors,
        markersize = sizes,
        markershapes = markers,
        label = "",
        markerstrokewidth = 0.5,
        markerstrokecolor = :black,
        markeralpha = 0.7,
    )
end

# Let's see how this plays out!
# ```julia
# model = initialise()
#
# frames = @animate for i in 0:200
#     i > 0 && step!(model, agent_step!, 1)
#     plotmap(model.space.m)
#     plotagents(model)
# end
#
# gif(frames, "outbreak.gif", fps = 15)
# ```
#
# ```@raw html
# <video width="auto" controls autoplay loop>
# <source src="https://raw.githubusercontent.com/JuliaDynamics/JuliaDynamics/master/videos/agents/zombies.mp4?raw=true" type="video/mp4">
# </video>
# ```

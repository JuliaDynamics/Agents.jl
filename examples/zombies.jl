# # Zombie Outbreak
# ![](outbreak.gif)
#
# This model showcases an ABM running on a map, using [`OpenStreetMapSpace`](@ref).
#
# ## Constructing the end of days
using Agents
using Random # hide

# We'll simulate a zombie outbreak in a city. To do so, we start with an agent which
# satisfies the OSMSpace conditions of having a position of type [`OSMPos`](@ref) and
# a `route` vector.

mutable struct Zombie <: AbstractAgent
    id::Int # Required
    pos::OSMPos # Required
    route::Vector{Int} # Required
    infected::Bool # User added
end

# The model constructor we build consists of a map, and 100 agents scattered randomly
# around it. They have their own agenda and need to travel to some new destination.
# Unfortunately one of the population has turned and will begin infecting anyone who
# comes close.

function initialise(; map_path = "test/data/reno_east3.osm")
    model = ABM(Zombie, OpenStreetMapSpace(map_path))

    for _ in 1:100
        start = osm_random_direction(model) # Somewhere on a road
        finish = random_position(model) # At an intersection

        ## We already have our start and finish edges, so we identify the in-between
        path = osm_plan_route(start[2], finish[1], model)
        ## Since we start on an edge, there are two possibilities here.
        ## 1. The route wants us to turn around, thus next id en-route will
        ## be pos[1]. That's fine.
        ## 2. The route wants us to move on, but start will be in the list,
        ## so we need to drop that.
        path[1] == start[2] && popfirst!(path)

        add_agent!(start, model, path, false)
    end

    patient_zero = random_agent(model)
    patient_zero.infected = true
    return model
end

# In our model, agents are seemingly oblivious to the problem, they keep going about their
# business, but start eating people along the way. Perhaps they can finally express their distaste
# for city commuting.

function agent_step!(agent, model)
    ## Each agent will progress 25 meters along their route
    move_agent!(agent, model, 25)

    if agent.pos[1] == agent.pos[2] && length(agent.route) == 0 && rand() < 0.1
        ## When stationary, give the agent a 10% chance of going somwhere else
        agent.route = osm_plan_route(agent.pos[1], random_position(model)[1], model)
        ## Drop current position
        popfirst!(agent.route)
        ## Start on new route
        move_agent!(agent, OSMPos(agent.pos[1], popfirst!(agent.route)), model)
    end

    if agent.infected
        ## Agents will be infected if they get within 50 meters of a zombie.
        map(i -> model[i].infected = true, nearby_ids(agent, model, 50))
    end
end

# ## Visualising the fall of humanity
#
# Plotting this space in a seemless manner is a work in progress. For now we
# use [OpenStreetMapXPlot](https://github.com/pszufe/OpenStreetMapXPlot.jl) and
# a custom routine.

using OpenStreetMapXPlot
using Plots
gr()

ac(agent) = agent.infected ? :green : :black
as(agent) = agent.infected ? 6 : 5

function plotagents(model)
    ## Essentially a cut down version on plotabm
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

Random.seed!(2490) # hide
model = initialise()

frames = @animate for i in 0:200
    i > 0 && step!(model, agent_step!, 1)
    plotmap(model.space.m)
    plotagents(model)
end

gif(frames, "outbreak.gif", fps = 15)


# # Zombie Outbreak
# ![](outbreak.gif)
#
# This model showcases an ABM running on a map, using [`OpenStreetMapSpace`](@ref).
#
# ## Constructing the end of days
using Agents
using Random # hide

# We'll simulate a zombie outbreak in a city. To do so, we start with an agent which
# satisfies the OSMSpace conditions of having a `pos`ition of type
# `Tuple{Int,Int,Float64}`, a `route` vector and a `destination` with the same type as
# `pos`. For simplicity though we shall build this with the [`@agent`](@ref) macro.

@agent Zombie OSMAgent begin
    infected::Bool
end

# The model constructor we build consists of a map, and 100 agents scattered randomly
# around it. They have their own agenda and need to travel to some new destination.
# Unfortunately one of the population has turned and will begin infecting anyone who
# comes close.

function initialise(; map_path = TEST_MAP)
    model = ABM(Zombie, OpenStreetMapSpace(map_path))

    for _ in 1:100
        start = random_position(model) # At an intersection
        finish = osm_random_road_position(model) # Somewhere on a road
        route = osm_plan_route(start, finish, model)
        add_agent!(start, model, route, finish, false)
    end

    ## We'll add patient zero at a specific (latitude, longitude)
    start = osm_road((39.534773980413505, -119.78937575923226), model)
    finish = osm_intersection((39.52530416953533, -119.76949287425508), model)
    route = osm_plan_route(start, finish, model)
    add_agent!(start, model, route, finish, true)
    return model
end

# In our model, zombies are seemingly oblivious to their state, since they keep going about their
# business, but start eating people along the way. Perhaps they can finally express their distaste
# for city commuting.

function agent_step!(agent, model)
    ## Each agent will progress 25 meters along their route
    move_agent!(agent, model, 25)

    if osm_is_stationary(agent) && rand() < 0.1
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

res = []
for i in 1:100
    Random.seed!(i) # hide 279, 31
    model = initialise()
    step!(model, agent_step!, 200)
    num = count(a -> a.infected, allagents(model))
    push!(res, (i, num))
end
bestidx = findmax(last.(res))[2]
first(res[bestidx])


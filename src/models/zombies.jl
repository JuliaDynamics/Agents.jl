using Random

@agent struct Zombie 
    fieldsof(OSMAgent)
    infected::Bool
    speed::Float64
end

"""
    zombies(; seed = 1234)
Same as in the [Zombie Outbreak](@ref) example.
"""
function zombies(; seed = 1234)
    map_path = OSM.test_map()
    properties = Dict(:dt => 1 / 60)
    model = ABM(
        Zombie,
        OpenStreetMapSpace(map_path);
        properties = properties,
        rng = Random.MersenneTwister(seed)
    )

    for id in 1:100
        start = random_position(model) # At an intersection
        speed = rand(abmrng(model)) * 5.0 + 2.0 # Random speed from 2-7kmph
        human = add_agent!(start, Zombie, model, false, speed)
        OSM.plan_random_route!(human, model; limit = 50) # try 50 times to find a random route
    end
    ## We'll add patient zero at a specific (latitude, longitude)
    start = OSM.nearest_road((51.5328328, 9.9351811), model)
    finish = OSM.nearest_node((51.530876112711745, 9.945125635913511), model)

    speed = rand(abmrng(model)) * 5.0 + 2.0 # Random speed from 2-7kmph
    zombie = add_agent!(start, model, true, speed)
    plan_route!(zombie, finish, model)
    ## This function call creates & adds an agent, see `add_agent!`
    return model, zombie_agent_step!, dummystep
end

function zombie_agent_step!(agent, model)
    ## Each agent will progress slightly along their route
    distance_left = move_along_route!(agent, model, agent.speed * model.dt)

    if is_stationary(agent, model) && rand(abmrng(model)) < 0.1
        ## When stationary, give the agent a 10% chance of going somewhere else
        OSM.plan_random_route!(agent, model; limit = 50)
        ## Start on new route
        move_along_route!(agent, model, distance_left)
    end

    if agent.infected
        ## Agents will be infected if they get too close (within 10m) to a zombie.
        map(i -> model[i].infected = true, nearby_ids(agent, model, 0.01))
    end
    return
end

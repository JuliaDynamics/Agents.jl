@agent Zombie OSMAgent begin
    infected::Bool
end

"""
    zombies(; seed = 1234)
Same as in the [Zombie Outbreak](@ref) example.
"""
function zombies(; seed = 1234)

    model = ABM(Zombie, OpenStreetMapSpace(map_path); rng = Random.MersenneTwister(seed))

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

function zombie_agent_step!(agent, model)
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

function schelling_with_scheduler(; numagents = 320, griddims = (20, 20), min_to_be_happy = 3, scheduler = Schedulers.Randomly())
    @assert numagents < prod(griddims)
    space = GridSpace(griddims, periodic = false)
    properties = Dict(:min_to_be_happy => min_to_be_happy)
    model = ABM(Models.SchellingAgent, space; properties, scheduler)
    for n in 1:numagents
        agent = Models.SchellingAgent(n, (1, 1), false, n < numagents / 2 ? 1 : 2)
        add_agent_single!(agent, model)
    end
    return model, Models.schelling_agent_step!, dummystep
end

function flocking_with_scheduler(;
    n_birds = 100,
    speed = 1.0,
    cohere_factor = 0.25,
    separation = 4.0,
    separate_factor = 0.25,
    match_factor = 0.01,
    visual_distance = 5.0,
    extent = (100, 100),
    spacing = visual_distance / 1.5,
    scheduler = Schedulers.Randomly()
)
    space2d = ContinuousSpace(extent, spacing)
    model = ABM(Models.Bird, space2d; scheduler)
    for _ in 1:n_birds
        vel = Tuple(rand(model.rng, 2) * 2 .- 1)
        add_agent!(
            model,
            vel,
            speed,
            cohere_factor,
            separation,
            separate_factor,
            match_factor,
            visual_distance,
        )
    end
    return model, Models.flocking_agent_step!, dummystep
end

@agent SchellingAgentA GridAgent{2} begin
    mood::Bool
end

@agent SchellingAgentB GridAgent{2} begin
    mood::Bool
end

function union_schelling_with_scheduler(; numagents = 320, griddims = (20, 20), min_to_be_happy = 3, scheduler = Schedulers.Randomly())
    @assert numagents < prod(griddims)
    space = GridSpace(griddims, periodic = false)
    properties = Dict(:min_to_be_happy => min_to_be_happy)
    model = ABM(Union{SchellingAgentA,SchellingAgentB}, space; properties, scheduler, warn = false)
    for n in 1:numagents
        agent_type = n < numagents / 2 ? SchellingAgentA : SchellingAgentB
        agent = agent_type(n, (1, 1), false)
        add_agent_single!(agent, model)
    end
    return model, union_schelling_agent_step!, dummystep
end

function union_schelling_agent_step!(agent, model)
    agent.mood == true && return # do nothing if already happy
    count_neighbors_same_group = 0
    for neighbor in nearby_agents(agent, model)
        if typeof(agent) == typeof(neighbor)
            count_neighbors_same_group += 1
        end
    end
    if count_neighbors_same_group ≥ model.min_to_be_happy
        agent.mood = true
    else
        move_agent_single!(agent, model)
    end
end

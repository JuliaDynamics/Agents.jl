# # Flock model

using Agents, Random, LinearAlgebra

mutable struct Bird <: AbstractAgent
    id::Int
    pos::NTuple{2,Float64}
    vel::NTuple{2,Float64}
    speed::Float64
    cohere_factor::Float64
    separation::Float64
    seperate_factor::Float64
    match_factor::Float64
    visual_distance::Float64
end

# The function `initialize_model` generates birds and returns a model object using default values.
function initialize_model(;n_birds=100, speed=1.0, cohere_factor=.25, separation=4.0,
    seperate_factor=.25, match_factor=.01, visual_distance=5.0, dims=(100,100), seed=0)
    Random.seed!(seed)

    space2d = ContinuousSpace(2; periodic=true, extend=dims)
    model = ABM(Bird, space2d, scheduler=random_activation)
    for _ in 1:n_birds
        vel = Tuple(rand(2)*2 .- 1)
        add_agent!(
            model, vel, speed, cohere_factor,separation, seperate_factor,
            match_factor,visual_distance
        )
    end
    index!(model)
    return model
end

# ## Defining the agent_step!
# `agent_step!` is the primary function called for each step and computes velocity
# according to the three rules defined above.
function agent_step!(bird, model)
    # Obtain the ids of neibhors within the bird's visual distance
    ids = nearby_agents(bird, model, bird.visual_distance)
    # Compute velocity based on rules defined above
    bird.vel = (bird.vel .+ cohere(bird, model, ids) .+ seperate(bird, model, ids)
        .+ match(bird, model, ids))./2
    bird.vel = bird.vel ./ norm(bird.vel)
    # Move bird according to new velocity and speed
    move_agent!(bird, model, bird.speed)
end

distance(a1, a2) = sqrt(sum((a1.pos .- a2.pos).^2))

get_heading(a1, a2) = a1.pos .- a2.pos

# cohere computes the average position of neighboring birds, weighted by importance
function cohere(bird, model, ids)
    N = max(length(ids), 1)
    coherence = (0.0,0.0)
    for id in ids
        coherence = coherence .+ get_heading(model[id], bird)
    end
    return coherence ./ N .* bird.cohere_factor
end

# seperate repells the bird away from neighboring birds
function seperate(bird, model, ids)
    seperation_vec = (0.0,0.0)
    N = max(length(ids), 1)
    for id in ids
        if distance(bird, model[id]) < bird.separation
            seperation_vec = seperation_vec .- get_heading(model[id], bird)
        end
    end
    return seperation_vec./N.*bird.seperate_factor
end

# match computes the average trajectory of neighboring birds, weighted by importance
function match(bird, model, ids)
    match_vector = (0.0,0.0)
    N = max(length(ids), 1)
    for id in ids
        match_vector = match_vector .+ model[id].vel
    end
    return match_vector ./ N .* bird.match_factor
end


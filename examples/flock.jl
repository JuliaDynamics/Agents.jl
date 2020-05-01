# # Flock model
# ![](flock.gif)
#
# The flock model illustrates how flocking behavior can emerge when each bird follows three simple rules:
#
# * maintain a minimum distance from other birds to avoid collision
# * fly towards the average position of neighbors
# * fly in the average direction of neighbors


# ## Defining the core structures

# We begin by calling the required packages and defining an agent type representing a bird.

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

# The fields `id` and `pos` are required for every agent.
# The field `vel` is required for using [`move_agent!`](@ref) in `ContinuousSpace`.
# `speed` defines how far the bird travels in the direction defined by `vel` per `step`.
# `seperation` defines the minimum distance a bird must maintain from its neighbors.
# `visual_distance` refers to the distance a bird can see and defines a radius of neighboring birds.
# The contribution of each rule defined above recieves an importance weight: `cohere_factor`
# is the importance of maintaining the average position of neighbors,
# `match_factor` is the importance of matching the average trajectory of neighboring birds,
# and `seperate_factor` is the importance of maining the minimum
# distance from neighboring birds.

# The function `initialize_model` generates birds and returns a model object using default values.
function initialize_model(;
    n_birds = 100,
    speed = 1.0,
    cohere_factor = 0.25,
    separation = 4.0,
    seperate_factor = 0.25,
    match_factor = 0.01,
    visual_distance = 5.0,
    dims = (100, 100),
)
    space2d = ContinuousSpace(2; periodic = true, extend = dims)
    model = ABM(Bird, space2d, scheduler = random_activation)
    for _ in 1:n_birds
        vel = Tuple(rand(2) * 2 .- 1)
        add_agent!(
            model,
            vel,
            speed,
            cohere_factor,
            separation,
            seperate_factor,
            match_factor,
            visual_distance,
        )
    end
    index!(model)
    return model
end

# ## Defining the agent_step!
# `agent_step!` is the primary function called for each step and computes velocity
# according to the three rules defined above.
function agent_step!(bird, model)
    ## Obtain the ids of neibhors within the bird's visual distance
    ids = space_neighbors(bird, model, bird.visual_distance)
    ## Compute velocity based on rules defined above
    bird.vel =
        (
            bird.vel .+ cohere(bird, model, ids) .+ seperate(bird, model, ids) .+
            match(bird, model, ids)
        ) ./ 2
    bird.vel = bird.vel ./ norm(bird.vel)
    ## Move bird according to new velocity and speed
    move_agent!(bird, model, bird.speed)
end

distance(a1, a2) = sqrt(sum((a1.pos .- a2.pos) .^ 2))

get_heading(a1, a2) = a1.pos .- a2.pos

# `cohere` computes the average position of neighboring birds, weighted by importance
function cohere(bird, model, ids)
    N = max(length(ids), 1)
    birds = model.agents
    coherence = (0.0, 0.0)
    for id in ids
        coherence = coherence .+ get_heading(birds[id], bird)
    end
    return coherence ./ N .* bird.cohere_factor
end

# `seperate` repells the bird away from neighboring birds
function seperate(bird, model, ids)
    seperation_vec = (0.0, 0.0)
    N = max(length(ids), 1)
    birds = model.agents
    for id in ids
        neighbor = birds[id]
        if distance(bird, neighbor) < bird.separation
            seperation_vec = seperation_vec .- get_heading(neighbor, bird)
        end
    end
    return seperation_vec ./ N .* bird.seperate_factor
end

# `match` computes the average trajectory of neighboring birds, weighted by importance
function match(bird, model, ids)
    match_vector = (0.0, 0.0)
    N = max(length(ids), 1)
    birds = model.agents
    for id in ids
        match_vector = match_vector .+ birds[id].vel
    end
    return match_vector ./ N .* bird.match_factor
end

# ## Running the model
Random.seed!(23182) # hide
n_steps = 500
model = initialize_model()
step!(model, agent_step!, n_steps)


# ## Plotting the birds
# The great thing about [`plotabm`](@ref) is its flexibility. We can incorporate the
# direction of the birds when plotting them, by making the "marker" function `am`
# create a `Shape`: a triangle with same orientation as the bird's velocity.
# It is as simple as defining the following function:
function bird_triangle(b::Bird)
    φ = atan(b.vel[2], b.vel[1])
    xs = [(i ∈ (0, 3) ? 2 : 1) * cos(i * 2π / 3 + φ) for i in 0:3]
    ys = [(i ∈ (0, 3) ? 2 : 1) * sin(i * 2π / 3 + φ) for i in 0:3]
    Shape(xs, ys)
end

# And here is the animation
using AgentsPlots
gr() # hide
Random.seed!(23182) # hide
cd(@__DIR__) #src
model = initialize_model()
e = model.space.extend
anim = @animate for i in 0:100
    i > 0 && step!(model, agent_step!, 1)
    p1 = plotabm(
        model;
        am = bird_triangle,
        as = 10,
        showaxis = false,
        grid = false,
        xlims = (0, e[1]),
        ylims = (0, e[2]),
    )
    title!(p1, "step $(i)")
end
gif(anim, "flock.gif", fps = 30)


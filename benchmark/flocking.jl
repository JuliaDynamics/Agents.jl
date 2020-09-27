using Agents
using BenchmarkTools
using LinearAlgebra

mutable struct Bird <: AbstractAgent
    id::Int
    pos::NTuple{2,Float64}
    vel::NTuple{2,Float64}
    speed::Float64
    cohere_factor::Float64
    separation::Float64
    separate_factor::Float64
    match_factor::Float64
    visual_distance::Float64
end

"""
```julia
flocking(;
n_birds = 100,
speed = 1.0,
cohere_factor = 0.25,
separation = 4.0,
separate_factor = 0.25,
match_factor = 0.01,
visual_distance = 5.0,
dims = (100, 100),
spacing = 1
)
```
Same as in [Flock model](@ref).
"""
function flocking(;
    n_birds = 100,
    speed = 1.0,
    cohere_factor = 0.25,
    separation = 4.0,
    separate_factor = 0.25,
    match_factor = 0.01,
    visual_distance = 5.0,
    dims = (10, 10),
    spacing = 0.1
    )
    
    space2d = CompartmentSpace(dims, spacing; periodic = true)
    model = ABM(Bird, space2d, scheduler = random_activation)
    for _ in 1:n_birds
        vel = Tuple(rand(2) * 2 .- 1)
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
    return model, flocking_agent_step!, dummystep
end

function flocking_agent_step!(bird, model)
    ## Obtain the ids of neighbors within the bird's visual distance
    ids = collect(nearby_ids(bird, model, bird.visual_distance))
    ## Compute velocity based on rules defined above
    bird.vel =
    (
    bird.vel .+ cohere(bird, model, ids) .+ separate(bird, model, ids) .+
    match(bird, model, ids)
    ) ./ 2
    bird.vel = bird.vel ./ norm(bird.vel)
    ## Move bird according to new velocity and speed
    move_agent!(bird, model, bird.speed)
end

distance(a1, a2) = sqrt(sum(abs2.(a1.pos .- a2.pos)))

get_heading(a1, a2) = a1.pos .- a2.pos

function cohere(bird, model, ids)
    N = max(length(ids), 1)
    birds = model.agents
    coherence = (0.0, 0.0)
    for id in ids
        coherence = coherence .+ get_heading(birds[id], bird)
    end
    return coherence ./ N .* bird.cohere_factor
end

function separate(bird, model, ids)
    seperation_vec = (0.0, 0.0)
    N = max(length(ids), 1)
    birds = model.agents
    for id in ids
        neighbor = birds[id]
        if distance(bird, neighbor) < bird.separation
            seperation_vec = seperation_vec .- get_heading(neighbor, bird)
        end
    end
    return seperation_vec ./ N .* bird.separate_factor
end

function match(bird, model, ids)
    match_vector = (0.0, 0.0)
    N = max(length(ids), 1)
    birds = model.agents
    for id in ids
        match_vector = match_vector .+ birds[id].vel
    end
    return match_vector ./ N .* bird.match_factor
end



# %% COMPARTMENT VERSION
println("\n\nTimes of COMPARTMENT space")
println("Full model stepping")
@btime step!(model, agent_step!, model_step!, 500) setup=((model, agent_step!, model_step!) = flocking())

model, agent_step!, model_step! = flocking()
step!(model, agent_step!, model_step!, 1)
a = random_agent(model)
aa = [random_agent(model) for i in 1:100]
sleep(1e-9)

println("Nearby Agents")
@btime nearby_ids($a, $model);
println("nearby positions")
@btime nearby_positions($a.pos, $model);


println("Move agent")
@btime move_agent!($a, $model);
println("Add agent")
@btime add_agent!($model, (-0.9670145669689216, 0.2547210773962555), 1.0, 0.25, 4.0, 0.25, 0.01, 5.0)

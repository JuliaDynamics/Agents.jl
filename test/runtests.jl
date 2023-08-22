using Test, Agents, Random, LinearAlgebra
using CSV, Arrow
using Agents.Graphs, Agents.DataFrames
using StatsBase: mean
using StableRNGs

using Distributed
addprocs(2)
@everywhere begin
    using Test, Agents, Random, LinearAlgebra
    using CSV, Arrow
    using Agents.Graphs, Agents.DataFrames
    using StatsBase: mean
    using StableRNGs
end

@agent Agent0 NoSpaceAgent begin end

@agent Agent1 GridAgent{2} begin end

@agent Agent2 NoSpaceAgent begin 
    weight::Float64
end

@agent Agent3 GridAgent{2} begin 
    weight::Float64
end

@agent Agent4 GridAgent{2} begin 
    p::Int
end

@agent Agent5 GraphAgent begin 
    weight::Float64
end

@agent Agent6 ContinuousAgent{2,Float64} begin 
    weight::Float64
end

@agent Agent7 GraphAgent begin 
    f1::Bool
    f2::Int
end

@agent Agent8 ContinuousAgent{2,Float64} begin 
    f1::Bool
    f2::Int
end

Agent8(id, pos; f1, f2) = Agent8(id, pos, f1, f2)

@agent SchellingAgent GridAgent{2} begin
    mood::Bool
    group::Int
end

@agent Bird ContinuousAgent{2,Float64} begin
    speed::Float64
    cohere_factor::Float64
    separation::Float64
    separate_factor::Float64
    match_factor::Float64
    visual_distance::Float64
end

function schelling_model(ModelType, SpaceType; numagents = 30, griddims = (8, 8), min_to_be_happy = 3)
    @assert numagents < prod(griddims)
    space = SpaceType(griddims, periodic = false)
    properties = Dict(:min_to_be_happy => min_to_be_happy)
    model = ModelType(SchellingAgent, space; properties, scheduler = Schedulers.Randomly(), rng=StableRNG(10))
    for n in 1:numagents
        agent = SchellingAgent(n, (1, 1), false, n < numagents / 2 ? 1 : 2)
        add_agent_single!(agent, model)
    end
    return model, schelling_model_agent_step!, dummystep
end

function schelling_model_agent_step!(agent, model)
    agent.mood == true && return
    count_neighbors_same_group = 0
    for neighbor in nearby_agents(agent, model)
        if agent.group == neighbor.group
            count_neighbors_same_group += 1
        end
    end
    if count_neighbors_same_group ≥ model.min_to_be_happy
        agent.mood = true
    else
        move_agent_single!(agent, model)
    end
end

function flocking_model(
    ModelType;
    n_birds = 10,
    speed = 1.0,
    cohere_factor = 0.25,
    separation = 4.0,
    separate_factor = 0.25,
    match_factor = 0.01,
    visual_distance = 2.0,
    extent = (10, 10),
    spacing = visual_distance,
)
    space2d = ContinuousSpace(extent; spacing)
    model = ModelType(Bird, space2d, scheduler = Schedulers.Randomly(), rng=StableRNG(10))
    for _ in 1:n_birds
        vel = rand(abmrng(model), SVector{2}) .* 2 .- 1

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
    return model, flocking_model_agent_step!, dummystep
end

function flocking_model_agent_step!(bird, model)
    neighbor_ids = nearby_ids(bird, model, bird.visual_distance)
    N = 0
    match = separate = cohere = (0.0, 0.0)
    for id in neighbor_ids
        N += 1
        neighbor = model[id].pos
        heading = neighbor .- bird.pos
        cohere = cohere .+ heading
        if euclidean_distance(bird.pos, neighbor, model) < bird.separation
            separate = separate .- heading
        end
        match = match .+ model[id].vel
    end
    N = max(N, 1)
    cohere = cohere ./ N .* bird.cohere_factor
    separate = separate ./ N .* bird.separate_factor
    match = match ./ N .* bird.match_factor
    bird.vel = (bird.vel .+ cohere .+ separate .+ match) ./ 2
    bird.vel = bird.vel ./ norm(bird.vel)
    move_agent!(bird, model, bird.speed)
end

@testset "Agents.jl Tests" begin
    include("model_creation_tests.jl")
    include("api_tests.jl")
    include("randomness_tests.jl")
    include("scheduler_tests.jl")
    include("model_access.jl")
    include("space_test.jl")
    include("grid_space_tests.jl")
    include("collect_tests.jl")
    include("continuous_space_tests.jl")
    include("osm_tests.jl")
    include("astar_tests.jl")
    include("graph_tests.jl")
    include("csv_tests.jl")
    include("jld2_tests.jl")
end

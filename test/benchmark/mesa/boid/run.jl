using BenchmarkTools
include("boid.jl")


# ## Running the model
function benchmark()
    n_steps = 100
    results = []
    for N in 100:100:400
        b = @benchmarkable step!(model, agent_step!, $n_steps) setup=(model = 
        initialize_model(n_birds=$N, 
        speed=1.0,
        cohere_factor=.25,
        separation=4.0,
        seperate_factor=.25,
        match_factor=.01,
        visual_distance=5.0,
        dims=(100,100)))
        
        j = run(b)
        push!(results, minimum(j.times)/1e9)
    end
    return results
end

print(benchmark())
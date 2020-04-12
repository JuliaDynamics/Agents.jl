using BenchmarkTools
include("boid.jl")


# ## Running the model
n_steps = 100
b = @benchmarkable step!(model, agent_step!, n_steps) setup=(model = initialize_model())

j = run(b)
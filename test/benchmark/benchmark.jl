using Agents
using BenchmarkTools
using Random
Random.seed!(10)

println("Forest fire model")
include("../test/forest_fire_defs.jl")
a = @benchmark data=step!(forest, dummystep, forest_step!, 100, Dict(:status => [length, count]), when=1:100) setup=(forest = model_initiation(f=0.05, d=0.8, p=0.01, griddims=(20, 20), seed=2))
display(a)

println("move_agent!")
a = @benchmark move_agent!(model.agents[1], (3,4), model) setup=(model = model_initiation(f=0.1, d=0.8, p=0.1, griddims=(100, 50), seed=2))
display(a)

println("id2agent")
a = @benchmark id2agent(250, model)
display(a)

println("kill_agent!")
a = @benchmark kill_agent!(model.agents[250], model) setup=(model = model_initiation(f=0.1, d=0.8, p=0.1, griddims=(100, 50), seed=2))
display(a)

println("Schelling model")
include("../test/schelling_defs.jl")
b = @benchmark data=step!(model, agent_step!, 10, [:pos, :mood, :group], when=1:10) setup=(model = instantiate_modelS(numagents=370, griddims=(20,20), min_to_be_happy=5))
display(a)

using Agents
using BenchmarkTools
using Random
Random.seed!(10)

println("Wolf Sheep Grass")
a = @benchmark step!(model, agent_step!, model_step!, 500) setup=((model, agent_step!, model_step!) = Models.predator_prey()) samples=100
display(a)

println("Flocking")
a = @benchmark step!(model, agent_step!, model_step!, 1000) setup=((model, agent_step!, model_step!) = Models.flocking()) samples=100
display(a)

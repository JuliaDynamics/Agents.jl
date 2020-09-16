using Agents
using BenchmarkTools
using Random
Random.seed!(10)

a = @benchmark step!(model, agent_step!, model_step!, 200) setup=((model, agent_step!, model_step!) = Models.predator_prey()) samples=100
println("Agents.jl WolfSheep (ms): ", minimum(a.times)*1e-6)

a = @benchmark step!(model, agent_step!, model_step!, 1000) setup=((model, agent_step!, model_step!) = Models.flocking()) samples=100
println("Agents.jl Flocking (ms): ", minimum(a.times)*1e-6)

using Agents, Random, StatsPlots
cd(@__DIR__)
include("Union_Functions.jl")

Random.seed!(2514)
n_steps = 500
times = Float64[]
n_types = [1,2,3,5,10,15]
for n in n_types
    println(n)
    t = run_simulation(n_steps, 50; n_types=n)
    push!(times, t)
end

pyplot()
plot(n_types, times, grid=false, xaxis="Number of types", yaxis="Time (seconds)",
    leg=false, ylims=(0,3.0))

savefig("results.png")

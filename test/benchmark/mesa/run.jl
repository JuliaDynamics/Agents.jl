using BenchmarkTools
include("forest_fire.jl")

function counter(model::ABM)
  on_fire = 0
  green = 0
  burned = 0
  for tree in values(model.agents)
    if tree.status == 1
      green += 1
    elseif tree.status == 2
      on_fire += 1
    else
      burned += 1
    end
  end
  return green, on_fire, burned
end

height=100
d=0.6
nsteps = 100
when = 1:nsteps

aggregators = Dict(:model => [counter])
size_range = 100:100:1000
acollect = [:model]
results = Float64[]
for width in size_range
  b = @benchmarkable data=step!(forest, tree_step!, nsteps,
  aggregators, when=when) setup=(forest=model_initiation(d=d,
  griddims=($width, height), seed=2))

  j = run(b)
  push!(results, minimum(j.times)/1e9)  # convert them to seconds
end

results

#=
0.0623855
0.1409112
0.2434189
0.3797918
0.8206902
0.7178797
0.9326405
1.364939
1.5469985
2.051536
=#

using BenchmarkTools
include("forest_fire.jl")

agent_properties = [:model]

height=100
d=0.6
nsteps = 100
when = collect(1:nsteps);


function counter(model::ABM)
  on_fire = 0
  green = 0
  burned = 0
  for tree in model.agents
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
aggregators = [counter]
size_range = 100:100:1000

results = Float64[]
for width in size_range
  b = @benchmarkable data=step!(dummystep, forest_step!, forest, nsteps, agent_properties, aggregators, when) setup=(forest=model_initiation(d=d, griddims=($width, height), seed=2))

  j = run(b)
  push!(results, minimum(j.times)/1e9)  # convert them to seconds
end

results

# 0.124292399
# 0.261890796
# 0.382272875
# 0.526156528
# 0.643057459
# 0.795138978
# 1.012378349
# 1.180964479
# 1.248486157
# 1.369958317

# Run the benchmarks for Julia (run.jl, and boid/run.jl) and Python (run.py and boid/run.py). Copy the results below and plot

using VegaLite
using DataFrames

## Agents.jl benchmark results 

# forest fire
jlresults = [
 0.0639249,
 0.142405601,
 0.257741999,
 0.371782101]

# boid
jlboid = 0.094316

# Mesa benchmark results

#forest fire
pyresults = [
0.8553307999998196,
2.0069307999999637,
3.3087123000000247,
4.781681599999956
]

# boid
pyboid = 1.0031417000000005


dd = DataFrame(runtime=vcat(pyresults./jlresults, [pyboid/jlboid]),
              model = vcat(fill("Forest fire", 4), ["Boid flockers"]))

p = @vlplot(
  width=100, height=300,
  data = dd,
  mark = :point,
  x = {"model:n", axis={title=""}},
  y = {:runtime, axis={title="Mesa/Agents run time"}},
  color = {"model:n", legend=false}
)
save("benchmark_mesa.png", p)

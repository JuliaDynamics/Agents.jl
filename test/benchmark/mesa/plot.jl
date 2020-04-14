# Run the benchmarks for Julia (run.jl, and boid/run.jl) and Python (run.py and boid/run.py). Copy the results below and plot

using VegaLite
using DataFrames

## Agents.jl benchmark results 

# forest fire
jlresults = [0.0639249, 0.142405601, 0.257741999, 0.371782101]

# boid
jlboid = [0.101076999, 0.270401899, 0.5469489, 0.8079563]

# Mesa benchmark results

#forest fire
pyresults = [0.8553307999998196, 2.0069307999999637, 3.3087123000000247, 4.781681599999956]

# boid
pyboid = [0.8770560000000387, 2.4145003999999517, 4.189664500000049, 6.677871200000027]


dd = DataFrame(runtime=vcat(pyresults./jlresults, pyboid./jlboid),
              model = vcat(fill("Forest fire", 4), fill("Boid flocking", 4)))

p = @vlplot(
  width=100, height=300,
  data = dd,
  mark = :circle,
  x = {"model:n", axis={title=""}},
  y = {:runtime, axis={title="Mesa/Agents run time"}},
  color = {"model:n", legend=false}
)
save("benchmark_mesa.svg", p)

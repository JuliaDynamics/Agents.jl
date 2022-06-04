# Contributing to Agents.jl

Thanks for taking the time to contribute.

Any contribution to Agents.jl is welcome in the following ways:

  * Modifying the code or documentation with a pull request.
  * Reporting bugs and suggestions in the issues section of the project's Github.

# Previewing Documentation Edits

Modifications to the documentation can be previewed by building the documentation locally, which is made possible by a script located in docs/make.jl. The Documenter package is required and can be installed by running `import Pkg; Pkg.add("Documenter")` in a REPL session. Then the documentation can be built and previewed in build/ first by running `julia docs/make.jl` from a terminal.

# Benchmarking

As Agents.jl is developed we want to monitor code efficiency through
_benchmarks_. A benchmark is a function or other bit of code whose execution is
timed so that developers and users can keep track of how long different API
functions take when used in various ways. Individual benchmarks can be organized
into _suites_ of benchmark tests. See the
[`benchmark`](https://github.com/JuliaDynamics/Agents.jl/tree/master/benchmark)
directory to view Agents.jl's benchmark suites. Follow these examples to add
your own benchmarks for your Agents.jl contributions.  See the BenchmarkTools
[quickstart guide](https://github.com/JuliaCI/BenchmarkTools.jl#quick-start),
[toy example benchmark
suite](https://github.com/JuliaCI/BenchmarkTools.jl/blob/master/benchmark/benchmarks.jl),
and the [BenchmarkTools.jl
manual](https://juliaci.github.io/BenchmarkTools.jl/dev/manual/#Benchmarking-basics)
for more information on how to write your own benchmarks.

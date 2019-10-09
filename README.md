# Agents: agent-based modeling framework in Julia

[![](https://img.shields.io/badge/Agents.jl-v1.1.8-blue.svg)](https://github.com/JuliaDynamics/Agents.jl) 
[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://JuliaDynamics.github.io/Agents.jl/stable)
[![](https://img.shields.io/badge/docs-latest-blue.svg)](https://JuliaDynamics.github.io/Agents.jl/dev)
[![status](http://joss.theoj.org/papers/11ec21a6bb0a6e9992c07f26a601d580/status.svg)](http://joss.theoj.org/papers/11ec21a6bb0a6e9992c07f26a601d580)
[![Build Status](https://travis-ci.org/JuliaDynamics/Agents.jl.svg?branch=master)](https://travis-ci.org/JuliaDynamics/Agents.jl)

Agents.jl is a [Julia](https://julialang.org/) framework for agent-based modeling (ABM). It provides a structure and components for quickly implementing agent-based models, run them in batch, collect data, and visualize them. To that end, it provides the following functionalities: 

* Default grids to run the simulations, including simple or toroidal 1D grids, simple or toroidal regular rectangular and triangular 2D grids, and simple or toroidal regular cubic 3D grids with von Neumann or Moore neighborhoods.
* Running the simulations in parallel on multiple cores.
* Automatic data collection in a `DataFrame` at desired intervals.
* Exploring the simulation results interactively in [Data Voyager 2](https://github.com/vega/voyager).
* Batch running and batch data collection.
* Visualizing agent distributions on grids.

Julia is a language that is especially suitable for ABMs, because a) [it runs fast](https://julialang.org/benchmarks/), b) it is easy to express your ideas in and quick to write, and c) it has rich and easy-to-use packages for data analysis.

Agents.jl is lightweight and modular. It has a short learning curve, and allows one to extend its capabilities and express complicated modeling scenarios. Agents.jl is inspired by [Mesa](https://github.com/projectmesa/mesa) framework for Python.


## Installation

Install using the following command inside Julia:

```julia
]add Agents
```

It is compatible with Julia 0.7+.

For a tutorial, read the docs: [![](https://img.shields.io/badge/docs-stable-blue.svg)](https://JuliaDynamics.github.io/Agents.jl/stable)


## Contributions

Any contribution to Agents.jl is welcome in the following ways:

  * Modifying the code or documentation with a pull request.
  * Reporting bugs and suggestions in the issues section of the project's Github.

### Previewing Documentation Edits

Modifications to the documentation can be previewed by building the documentation locally, which is made possible by a script located in docs/make.jl. The Documenter package is required and can be installed by running `import Pkg; Pkg.add("Documenter")` in a REPL session. Then the documentation can be built and previewed in build/ first by running `julia docs/make.jl` from a terminal.

## Citation

If you use this package in a publication, please cite the paper below:

R. Vahdati, Ali (2019). Agents.jl: agent-based modeling framework in Julia. Journal of Open Source Software, 4(42), 1611, https://doi.org/10.21105/joss.01611
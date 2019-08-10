# Agents: agent-based modeling framework in Julia

[![](https://img.shields.io/badge/Agents.jl-v1.1.7-blue.svg)](https://github.com/kavir1698/Agents.jl) 
[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://kavir1698.github.io/Agents.jl/stable)
[![](https://img.shields.io/badge/docs-latest-blue.svg)](https://kavir1698.github.io/Agents.jl/dev)
[![Build Status](https://travis-ci.org/kavir1698/Agents.jl.svg?branch=master)](https://travis-ci.org/kavir1698/Agents.jl)

Agents.jl is a [Julia](https://julialang.org/) framework for agent-based modeling (ABM). It provides a structure and components for quickly implementing agent-based models, run them in batch, collect data, and visualize them. To that end, it provides the following functionalities: 

* Default grids to run the simulation, including simple or toroidal 1D grids, simple or toroidal regular rectangular and triangular 2D grids, and simple or toroidal regular cubic 3D grids with von Neumann or Moore neighborhoods. More space structure are to be implemented include arbitrary random networks.
* Running the simulations in parallel on multiple cores.
* Automatic data collection in a `DataFrame` at desired intervals.
* Exploring the simulation results interactively in [Data Voyager 2](https://github.com/vega/voyager).
* Batch running and batch data collection
* Visualize agent distributions on grids

Julia is a language that is especially suitable for ABMs, because a) [it runs fast](https://julialang.org/benchmarks/), b) it is easy to express your ideas in and quick to write, and c) it has rich and easy-to-use packages for data analysis.

Agents.jl is lightweight and modular. It has a short learning curve, and allows one to extend its capabilities and express complicated modeling scenarios. Agents.jl is inspired by [Mesa](https://github.com/projectmesa/mesa) framework for Python.


## Installation

Install using the following command inside Julia:

```julia
]add Agents
```

It is compatible with Julia 0.7+.

For a tutorial, read the docs: [![](https://img.shields.io/badge/docs-stable-blue.svg)](https://kavir1698.github.io/Agents.jl/stable)

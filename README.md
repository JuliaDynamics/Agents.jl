# Agents: agent-based modeling framework in Julia

[![](https://img.shields.io/badge/Agents.jl-v0.1-blue.svg)](https://github.com/kavir1698/Agents.jl) 
[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://kavir1698.github.io/Agents.jl/stable)
[![](https://img.shields.io/badge/docs-latest-blue.svg)](https://kavir1698.github.io/Agents.jl/dev)
[![Build Status](https://travis-ci.org/kavir1698/Agents.jl.svg?branch=master)](https://travis-ci.org/kavir1698/Agents.jl)

Agents.jl is a [Julia](https://julialang.org/) framework for agent-based modeling (ABM). It provides a structure and components for quickly implementing agent-based models, run them in batch, collect data, and visualize them. To that end, it provides the following functionalities: 

* Default grids to run the simulation, including simple or toroidal 1D grids, simple or toroidal regular rectangular and triangular 2D grids, and simple or toroidal regular cubic 3D grids with rectangular or triangle connections. More space structure are to be implemented include arbitrary random networks.
* Running the simulations in parallel on multiple cores or on clusters. (This is not ready yet)
* Automatic data collection in a `DataFrame` at desired intervals.
* Exploring the simulation results interactively in [Data Voyegar 2](https://github.com/vega/voyager).

Julia is a language that is especially suitable for ABMs, because a) [it runs fast](https://julialang.org/benchmarks/), b) it is easy to express your ideas in and quick to write, and c) it has rich and easy-to-use packages for data analysis.

Agents.jl is lightweight and modular. It has a short learning curve, and allows one to extend its capabilities and express complicated modeling scenarios. Agents.jl is inspired by [Mesa](https://github.com/projectmesa/mesa) framework for Python.


## Installation

Currently, the package is not registered to Julia's package list, therefore, install is using this command:

```julia
]add https://github.com/kavir1698/Agents.jl.git
```

It is compatible with Julia 0.7+.

For a tutorial, read the docs: [![](https://img.shields.io/badge/docs-stable-blue.svg)](https://kavir1698.github.io/Agents.jl/stable)

This is still work in progress. I am working on the following:

* Adding more unit tests
* Implementing more examples
* Implementing arbitrary network spaces
* Better batch data collector
* Parallel computing of batch simulations
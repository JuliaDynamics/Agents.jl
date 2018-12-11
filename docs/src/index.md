# Agents.jl Documentation

This is an agent-based modeling framework. It provides the following components for your modeling:

* Default grids to run the simulation
* Multi-core simulations
* Storing data in a `DataFrame` at your desired intervals
* Basic plots

You will only have to write functions about how an agent behaves in each step of the simulation and how model-level parameters change.

```@docs
step!(agent_step, model::AbstractModel)
AbstractModel
```
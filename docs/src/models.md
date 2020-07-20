# Predefined Models
Predefined agent based models exist in the `Models` submodule in the form of functions that return `model, agent_step!, model_step!` when called.

They are accessed like:
```julia
using Agents
model, agent_step!, model_step! = Models.flocking(; kwargs...)
```

The Examples section of the docs outline how to use and interact with each model.

So far, the predefined models that exist in the `Models` sub-module are:
```@autodocs
Modules = [Models]
Order   = [:function]
```

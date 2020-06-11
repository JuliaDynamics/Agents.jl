# Predefined Models
Predefined agent based models exist in the `Models` submodule in the form of functions that return `model, agent_step!, model_step!` when called.
They are the versions already explained in the Examples section of the docs.

They are accessed like:
```julia
using Agents
model, agent_step!, model_step! = Models.flocking(; kwargs...)
```

So far, the predefined models that exist in the `Models` sub-module are:
```@autodocs
Modules = [Models]
Order   = [:function]
```

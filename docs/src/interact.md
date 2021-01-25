# [Interactive application](@id Interact)
The interactive application of Agents.jl is _model-agnostic_.
This means that provided that the space of the model is one of the supported types (currently only 2D `GridSpace` or `ContinuousSpace`), the application does not care about the model dynamics or agent properties.

The app is based on [`InteractiveChaos`](https://juliadynamics.github.io/InteractiveChaos.jl/dev/), another package of JuliaDynamics.

Here is an example application made with [`InteractiveChaos.abm_data_exploration`](@ref).

```@raw html
<video width="100%" height="auto" controls autoplay loop>
<source src="https://raw.githubusercontent.com/JuliaDynamics/JuliaDynamics/master/videos/interact/agents.mp4?raw=true" type="video/mp4">
</video>
```

The animation at the start of this page was done with:
```julia
using Agents, Random
using InteractiveChaos
using GLMakie

model, agent_step!, model_step! = Models.forest_fire()

alive(model) = count(a.status == :green for a in allagents(model))
burning(model) = count(a.status == :burning for a in allagents(model))
mdata = [alive, burning, nagents]
mlabels = ["alive", "burning", "total"]

params = Dict(
    :f => 0.02:0.01:1.0,
    :p => 0.01:0.01:1.0,
)

ac(a) = a.status ? "#1f851a" : "#67091b"
am = :rect

p1 = abm_data_exploration(model, agent_step!, model_step!, params;
ac = ac, as = 1, am = am, mdata, mlabels)
```

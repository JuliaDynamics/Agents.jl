# Interactive application
The interactive application of Agents.jl is _model-agnostic_.
This means that provided that the space of the model is one of the supported types (currently only 2D `GridSpace` or `ContinuousSpace`), the application does not care about the model dynamics or agent properties.

The app is based on [`InteractiveChaos`](https://juliadynamics.github.io/InteractiveChaos.jl/dev/), another package of JuliaDynamics.

Here is an example application

```@raw html
<video width="100%" height="auto" controls autoplay loop>
<source src="https://raw.githubusercontent.com/JuliaDynamics/JuliaDynamics/master/videos/interact/agents.mp4?raw=true" type="video/mp4">
</video>
```

the application is made with the following function:

```@docs
InteractiveChaos.interactive_abm
```

The animation at the start of this page was done with:
```julia
using Agents, Random
using Makie
using InteractiveChaos

model, model_step!, agent_step! = Models.forest_fire()

alive(model) = count(a.status for a in allagents(model))
burning(model) = count(!a.status for a in allagents(model))
mdata = [alive, burning, nagents]
mlabels = ["alive", "burning", "total"]

params = Dict(
    :f => 0.02:0.01:1.0,
    :p => 0.01:0.01:1.0,
)

ac(a) = a.status ? "#1f851a" : "#67091b"
am = :rect

p1 = interactive_abm(model, model_step!, agent_step!, params;
ac = ac, as = 1, am = am, mdata = mdata, mlabels=mlabels)
```

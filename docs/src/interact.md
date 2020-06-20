# Interactive application
The interactive applications of Agents.jl work for _any_ agent based model, and are created on the principle of simplicity and generality.
They are based on [`InteractiveChaos`](https://juliadynamics.github.io/InteractiveChaos.jl/dev/), another package of JuliaDynamics.

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

model, agent_step!, model_step! = Models.forest_fire()

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

p1 = interactive_abm(model, agent_step!, model_step!, params;
ac = ac, as = 1, am = am, mdata = mdata, mlabels=mlabels)
```

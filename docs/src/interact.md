# Plotting and interactive application
Plotting and interaction functionality comes from [`InteractiveDynamics`](https://juliadynamics.github.io/InteractiveDynamics.jl/dev/), another package of JuliaDynamics, which uses Makie.jl.

Plotting, and the interactive application of Agents.jl, are _model-agnostic_ and _simple to use_. Defining simple functions that map agents to colors, and shapes, is the only thing you need to do. If you have defined already an ABM and functions for stepping the model, you typically need to write an extra couple of lines of code only to get your visualizations going.

You need to install both `InteractiveDynamics`, as well as a plotting backend (we recommend `GLMakie`) to use the following functions.

The version of `InteractiveDynamics` used in the docs is:
```@example versions
using Pkg
Pkg.status("InteractiveDynamics")
```

Some parts of Agents.jl cannot be plotted yet in Makie.jl, and therefore alternatives are provided. However in the near future we hope to have moved everything to plotting with Makie.jl and not necessitate usage of Plots.jl or other libraries.

## Plotting
The following functions allow you to plot an ABM, animate it via play/pause buttons, or directly export the time evolution into a video. At the moment these functions support 2D continuous and discrete space.

```@docs
abm_plot
abm_play
abm_video
```

## Interactive application

```@docs
InteractiveDynamics.abm_data_exploration
```

Here is an example application made with [`InteractiveDynamics.abm_data_exploration`](@ref).

```@raw html
<video width="100%" height="auto" controls autoplay loop>
<source src="https://raw.githubusercontent.com/JuliaDynamics/JuliaDynamics/master/videos/interact/agents.mp4?raw=true" type="video/mp4">
</video>
```

the application is made with the following script:

```julia
using InteractiveDynamics, Agents, Random, Statistics
import GLMakie

Random.seed!(165) # hide
model, agent_step!, model_step! = Models.daisyworld(;
    solar_luminosity = 1.0, solar_change = 0.0, scenario = :change
)
Daisy, Land = Agents.Models.Daisy, Agents.Models.Land

# Parameter define agent color and shape:
using GLMakie.AbstractPlotting: to_color
daisycolor(a::Daisy) = RGBAf0(to_color(a.breed))
landcolor = cgrad(:thermal)
daisycolor(a::Land) = to_color(landcolor[(a.temperature+50)/150])

daisyshape(a::Daisy) = '♣'
daisysize(a::Daisy) = 15
daisyshape(a::Land) = :rect
daisysize(a::Land) = 20
landfirst = by_type((Land, Daisy), false) # scheduler

# Parameter exploration and data collection:
params = Dict(
    :solar_change => -0.1:0.01:0.1,
    :surface_albedo => 0:0.01:1,
)

black(a) = a.breed == :black
white(a) = a.breed == :white
daisies(a) = a isa Daisy
land(a) = a isa Land
adata = [(black, count, daisies), (white, count, daisies), (:temperature, mean, land)]
mdata = [:solar_luminosity]

alabels = ["black", "white", "T"]
mlabels = ["L"]

model, agent_step!, model_step! = Models.daisyworld(; solar_luminosity = 1.0, solar_change = 0.0, scenario = :change)

fig, adf, mdf = abm_data_exploration(
    model, agent_step!, model_step!, params;
    ac = daisycolor, am = daisyshape, as = daisysize,
    mdata, adata, alabels, mlabels,
    scheduler = landfirst # crucial to change model scheduler!
)
```

## Graph plotting
To plot agents existing of a [`GraphSpace`](@ref) we can't use `InteractiveDynamics` because Makie.jl does not support plotting on graphs (yet).

## Open Street Map plotting

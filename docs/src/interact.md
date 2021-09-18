# Plotting and interactive application
Plotting and interaction functionality comes from [`InteractiveDynamics`](https://juliadynamics.github.io/InteractiveDynamics.jl/dev/), another package of JuliaDynamics, which uses Makie.jl.

Plotting, and the interactive application of Agents.jl, are _model-agnostic_ and _simple to use_. Defining simple functions that map agents to colors, and shapes, is the only thing you need to do. If you have already defined an ABM and functions for stepping the model, you typically need to write only an extra couple of lines of code to get your visualizations going. All models in the Examples showcase plotting.

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
InteractiveDynamics.abm_plot
InteractiveDynamics.abm_play
InteractiveDynamics.abm_video
```

## Interactive application

```@docs
InteractiveDynamics.abm_data_exploration
```

Here is an example application made with [`InteractiveDynamics.abm_data_exploration`](@ref) from the [Daisyworld](@ref) example.

## Graph plotting
To plot agents existing of a [`GraphSpace`](@ref) we can't use `InteractiveDynamics` because Makie.jl does not support plotting on graphs (yet). We provide the following function in this case, which comes into scope when `using Plots`. See also the [SIR model for the spread of COVID-19](@ref) example for an application.
```@docs
abm_plot_on_graph
```

## Open Street Map plotting
Plotting an open street map is also not possible with Makie.jl at the moment, but there is a Julia package that does this kind of plotting, OpenStreetMapXPlots.jl. Its usage is demonstrated in the [Zombie Outbreak](@ref) example page.

## Plots.jl Recipes
Whilst the primary method for plotting agents models is through `InteractiveDynamics`, the following Plots recipes can also be used if you prefer the Plots.jl ecosystem.

Notice that these methods will emit a warning. Pass `warn = false` to suppress it.

```@docs
plotabm
plotabm!
```


# # Visualizations and Animations for Agent Based Models
# ```@raw html
# <video width="100%" height="auto" controls autoplay loop>
# <source src="https://raw.githubusercontent.com/JuliaDynamics/JuliaDynamics/master/videos/interact/agents.mp4?raw=true" type="video/mp4">
# </video>
# ```

# This page describes functions that can be used with the [Makie](https://docs.makie.org/stable/)
# plotting ecosystem to animate and interact with agent based models.
# ALl the functionality described here uses Julia's package extensions and therefore comes
# into scope once `Makie` (or any of its backends such as `CairoMakie`) gets loaded.

# The animation at the start of the page is created using the code of this page, see below.

# The docs are built using versions:
using Pkg
Pkg.status(["Agents", "CairoMakie"];
    mode = PKGMODE_MANIFEST, io=stdout
)

# ## Static plotting of ABMs

# Static plotting, which is also the basis for creating custom plots that include
# an ABM plot, is done using the [`abmplot`](@ref) function. Its usage is exceptionally
# straight-forward, and in principle one simply defines functions for how the
# agents should be plotted. Here we will use a pre-defined model, the Daisyworld
# as an example throughout this docpage.
# To learn about this model you can visit the [example hosted at AgentsExampleZoo
# ](https://juliadynamics.github.io/AgentsExampleZoo.jl/dev/examples/daisyworld/),
using Agents, CairoMakie

# TODO: when AgentsExampleZoo is released, remove these Pkg commands #hide
try
    using Pkg
    Pkg.develop(url="https://github.com/JuliaDynamics/AgentsExampleZoo.jl.git")
    using AgentsExampleZoo
catch
    Pkg.develop(path=joinpath(DEPOT_PATH[1],"dev","AgentsExampleZoo"))
    using AgentsExampleZoo
end

model = AgentsExampleZoo.daisyworld(; solar_luminosity = 1.0, solar_change = 0.0, 
    scenario = :change)
model

# Now, to plot daisyworld we provide a function for the color
# for the agents that depend on the agent properties, and
# a size and marker style that are constants,
daisycolor(a) = a.breed # agent color
as = 20    # agent size
am = '✿'  # agent marker
scatterkwargs = (strokewidth = 1.0,) # add stroke around each agent
fig, ax, abmobs = abmplot(model; ac = daisycolor, as, am, scatterkwargs)
fig

# Besides agents, we can also plot spatial properties as a heatmap.
# Here we plot the temperature of the planet by providing the name
# of the property as the "heat array":
heatarray = :temperature
heatkwargs = (colorrange = (-20, 60), colormap = :thermal)
plotkwargs = (;
    ac = daisycolor, as, am,
    scatterkwargs = (strokewidth = 1.0,),
    heatarray, heatkwargs
)

fig, ax, abmobs = abmplot(model; plotkwargs...)
fig


# ```@docs
# abmplot
# ```

# ## Interactive ABM Applications

# Continuing from the Daisyworld plots above, we can turn them into interactive
# applications straightforwardly, simply by providing the stepping functions
# as illustrated in the documentation of [`abmplot`](@ref).
# Note that [`GLMakie`](https://makie.juliaplots.org/v0.15/documentation/backends_and_output/)
# should be used instead of `CairoMakie` when wanting to use the interactive
# aspects of the plots.
fig, ax, abmobs = abmplot(model; plotkwargs...)
fig

# One could click the run button and see the model evolve.
# Furthermore, one can add more sliders that allow changing the model parameters.
params = Dict(
    :surface_albedo => 0:0.01:1,
    :solar_change => -0.1:0.01:0.1,
)
fig, ax, abmobs = abmplot(model; params, plotkwargs...)
fig

# One can furthermore collect data while the model evolves and visualize them using the
# convenience function [`abmexploration`](@ref)
using Statistics: mean
black(a) = a.breed == :black
white(a) = a.breed == :white
adata = [(black, count), (white, count)]
temperature(model) = mean(model.temperature)
mdata = [temperature, :solar_luminosity]
fig, abmobs = abmexploration(model;
    params, plotkwargs...,  adata, alabels = ["Black daisys", "White daisys"], 
    mdata, mlabels = ["T", "L"]
)
nothing #hide

# ```@raw html
# <video width="100%" height="auto" controls autoplay loop>
# <source src="https://raw.githubusercontent.com/JuliaDynamics/JuliaDynamics/master/videos/interact/agents.mp4?raw=true" type="video/mp4">
# </video>
# ```

# ```@docs
# abmexploration
# ```

# ## ABM Videos
# ```@docs
# abmvideo
# ```
# E.g., continuing from above,
model = AgentsExampleZoo.daisyworld()
abmvideo("daisyworld.mp4", model; title = "Daisy World", frames = 150, plotkwargs...)

# ```@raw html
# <video width="auto" controls autoplay loop>
# <source src="../daisyworld.mp4" type="video/mp4">
# </video>
# ```


# ## Agent inspection

# It is possible to inspect agents at a given position by hovering the mouse cursor over
# the scatter points in the agent plot. Inspection is automatically enabled for interactive
# applications (i.e. when either agent or model stepping functions are provided). To
# manually enable this functionality, simply add `enable_inspection = true` as an
# additional keyword argument to the `abmplot`/`abmplot!` call.
# A tooltip will appear which by default provides the name of the agent type, its `id`,
# `pos`, and all other fieldnames together with their current values. This is especially
# useful for interactive exploration of micro data on the agent level.

# ![RabbitFoxHawk inspection example](https://github.com/JuliaDynamics/JuliaDynamics/tree/master/videos/agents/RabbitFoxHawk_inspection.png)

# The tooltip can be customized by extending `Agents.agent2string`.
# ```@docs
# Agents.agent2string
# ```

# ## Creating custom ABM plots
# The existing convenience function [`abmexploration`](@ref) will
# always display aggregated collected data as scatterpoints connected with lines.
# In cases where more granular control over the displayed plots is needed, we need to take
# a few extra steps and utilize the [`ABMObservable`](@ref) returned by [`abmplot`](@ref).
# The same steps are necessary when we want to create custom plots that compose
# animations of the model space and other aspects.

# ```@docs
# ABMObservable
# ```
# To do custom animations you need to have a good idea of how Makie's animation system works.
# Have a look [at this tutorial](https://www.youtube.com/watch?v=L-gyDvhjzGQ) if you are
# not familiar yet.

# create a basic abmplot with controls and sliders
model = daisyworld(; solar_luminosity = 1.0, solar_change = 0.0, scenario = :change)
fig, ax, abmobs = abmplot(model; params, plotkwargs...,
    adata, mdata, figure = (; resolution = (1600,800))
)
fig

#

abmobs

#

# create a new layout to add new plots to the right of the abmplot
plot_layout = fig[:,end+1] = GridLayout()

# create a sublayout on its first row and column
count_layout = plot_layout[1,1] = GridLayout()

# collect tuples with x and y values for black and white daisys
blacks = @lift(Point2f.($(abmobs.adf).step, $(abmobs.adf).count_black))
whites = @lift(Point2f.($(abmobs.adf).step, $(abmobs.adf).count_white))

# create an axis to plot into and style it to our liking
ax_counts = Axis(count_layout[1,1];
    backgroundcolor = :lightgrey, ylabel = "Number of daisies by color")

# plot the data as scatterlines and color them accordingly
scatterlines!(ax_counts, blacks; color = :black, label = "black")
scatterlines!(ax_counts, whites; color = :white, label = "white")

# add a legend to the right side of the plot
Legend(count_layout[1,2], ax_counts; bgcolor = :lightgrey)

# and another plot, written in a more condensed format
ax_hist = Axis(plot_layout[2,1];
    ylabel = "Distribution of mean temperatures\nacross all time steps")
hist!(ax_hist, @lift($(abmobs.mdf).temperature);
    bins = 50, color = :red,
    strokewidth = 2, strokecolor = (:black, 0.5),
)

fig

# Now, once we step the `abmobs::ABMObservable`, the whole plot will be updated
Agents.step!(abmobs, 1)
Agents.step!(abmobs, 1)
fig

# Of course, you need to actually adjust axis limits given that the plot is interactive
autolimits!(ax_counts)
autolimits!(ax_hist)

# Or, simply trigger them on any update to the model observable:
on(abmobs.model) do m
    autolimits!(ax_counts)
    autolimits!(ax_hist)
end

# and then marvel at everything being auto-updated by calling `step!` :)

for i in 1:100; step!(abmobs, 1); end
fig

# ## GraphSpace models
# While the `ac, as, am` keyword arguments generally relate to *agent* colors, markersizes,
# and markers, they are handled a bit differently in the case of [`GraphSpace models`](https://juliadynamics.github.io/Agents.jl/stable/api/#Agents.GraphSpace).
# Here, we collect those plot attributes for each node of the underlying graph which can
# contain multiple agents.
# If we want to use a function for this, we therefore need to handle an iterator of agents.
# Keeping this in mind, we can create an [exemplary GraphSpace model](https://juliadynamics.github.io/Agents.jl/stable/examples/sir/)
# and plot it with [`abmplot`](@ref).
using Graphs
using ColorTypes
sir_model = AgentsExampleZoo.sir()
city_size(agents_here) = 0.005 * length(agents_here)
function city_color(agents_here)
    l_agents_here = length(agents_here)
    infected = count(a.status == :I for a in agents_here)
    recovered = count(a.status == :R for a in agents_here)
    return RGB(infected / l_agents_here, recovered / l_agents_here, 0)
end

# To further style the edges and nodes of the resulting graph plot, we can leverage
# the functionality of [GraphMakie.graphplot](https://graph.makie.org/stable/#GraphMakie.graphplot)
# and pass all the desired keyword arguments to it via a named tuple called
# `graphplotkwargs`.
# When using functions for edge color and width, they should return either one color or
# a vector with the same length (or twice) as current number of edges in the underlying
# graph.
# In the example below, the `edge_color` function colors all edges to a semi-transparent
# shade of grey and the `edge_width` function makes use of the special ability of
# `linesegments` to be tapered (i.e. one end is wider than the other).
using GraphMakie: Shell
edge_color(model) = fill((:grey, 0.25), ne(abmspace(model).graph))
function edge_width(model)
    w = zeros(ne(abmspace(model).graph))
    for e in edges(abmspace(model).graph)
        w[e.src] = 0.004 * length(abmspace(model).stored_ids[e.src])
        w[e.dst] = 0.004 * length(abmspace(model).stored_ids[e.dst])
    end
    return w
end
graphplotkwargs = (
    layout = Shell(), # node positions
    arrow_show = false, # hide directions of graph edges
    edge_color = edge_color, # change edge colors and widths with own functions
    edge_width = edge_width,
    edge_plottype = :linesegments # needed for tapered edge widths
)

fig, ax, abmobs = abmplot(sir_model; as = city_size, ac = city_color, graphplotkwargs)
fig

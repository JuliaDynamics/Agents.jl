"""
    abmplot(model::ABM; kwargs...) → fig, ax, abmobs
    abmplot!(ax::Axis/Axis3, model::ABM; kwargs...) → abmobs

Plot an agent based model by plotting each individual agent as a marker and using
the agent's position field as its location on the plot. The same function is used
to make custom composite plots and animations for the model evolution
using the returned `abmobs`. `abmplot` is also used to launch interactive GUIs for
evolving agent based models, see "Interactivity" below.

See also [`abmvideo`](@ref) and [`abmexploration`](@ref).

## Keyword arguments

### Agent related
* `ac, as, am` : These three keywords decide the color, size, and marker, that
  each agent will be plotted as. They can each be either a constant or a *function*,
  which takes as an input a single agent and outputs the corresponding value. If the model
  uses a `GraphSpace`, `ac, as, am` functions instead take an *iterable of agents* in each
  position (i.e. node of the graph).

  Using constants: `ac = "#338c54", as = 15, am = :diamond`

  Using functions:
  ```julia
  ac(a) = a.status == :S ? "#2b2b33" : a.status == :I ? "#bf2642" : "#338c54"
  as(a) = 10rand()
  am(a) = a.status == :S ? :circle : a.status == :I ? :diamond : :rect
  ```
  Notice that for 2D models, `am` can be/return a `Makie.Polygon` instance, which plots each agent
  as an arbitrary polygon. It is assumed that the origin (0, 0) is the agent's position when
  creating the polygon. In this case, the keyword `as` is meaningless, as each polygon has
  its own size. Use the functions `scale, rotate_polygon` to transform this polygon.

  3D models currently do not support having different markers. As a result, `am` cannot be
  a function. It should be a `Mesh` or 3D primitive (such as `Sphere` or `Rect3D`).
* `offset = nothing` : If not `nothing`, it must be a function taking as an input an
  agent and outputting an offset position tuple to be added to the agent's position
  (which matters only if there is overlap).
* `scatterkwargs = ()` : Additional keyword arguments propagated to the `scatter!` call.

### Preplot related
* `heatarray = nothing` : A keyword that plots a model property (that is a matrix)
  as a heatmap over the space.
  Its values can be standard data accessors given to functions like `run!`, i.e.
  either a symbol (directly obtain model property) or a function of the model.
  If the space is `AbstractGridSpace` then matrix must be the same size as the underlying
  space. For `ContinuousSpace` any size works and will be plotted over the space extent.
  For example `heatarray = :temperature` is used in the Daisyworld example.
  But you could also define `f(model) = create_matrix_from_model...` and set
  `heatarray = f`. The heatmap will be updated automatically during model evolution
  in videos and interactive applications.
* `heatkwargs = NamedTuple()` : Keywords given to `Makie.heatmap` function
  if `heatarray` is not nothing.
* `add_colorbar = true` : Whether or not a Colorbar should be added to the right side of the
  heatmap if `heatarray` is not nothing. It is strongly recommended to use `abmplot`
  instead of the `abmplot!` method if you use `heatarray`, so that a colorbar can be
  placed naturally.
* `static_preplot!` : A function `f(ax, model)` that plots something after the heatmap
  but before the agents.
* `osmkwargs = NamedTuple()` : keywords directly passed to `OSMMakie.osmplot!`
  if model space is `OpenStreetMapSpace`.
* `graphplotkwargs = NamedTuple()` : keywords directly passed to
  [`GraphMakie.graphplot!`](https://graph.makie.org/stable/#GraphMakie.graphplot)
  if model space is `GraphSpace`.
* `adjust_aspect = true`: Adjust axis aspect ratio to be the model's space aspect ratio.
* `enable_space_checks = true`: Set to `false` to disable checks related to the model
  space.

The stand-alone function `abmplot` also takes two optional `NamedTuple`s named `figure` and
`axis` which can be used to change the automatically created `Figure` and `Axis` objects.

# Interactivity

## Evolution related
* `add_controls::Bool`: If `true`, `abmplot` switches to "interactive application" mode.
  This is by default `true` if the model contains either `agent_step!` or `model_step!`.
  The model evolves interactively using `Agents.step!`.
  The application has the following interactive elements:
  1. "step": advances the simulation once for `spu` steps.
  1. "run": starts/stops the continuous evolution of the model.
  1. "reset model": resets the model to its initial state from right after starting the
     interactive application.
  1. Two sliders control the animation speed: "spu" decides how many model steps should be
     done before the plot is updated, and "sleep" the `sleep()` time between updates.
* `enable_inspection = add_controls`: If `true`, enables agent inspection on mouse hover.
* `spu = 1:50`: The values of the "spu" slider.
* `params = Dict()` : This is a dictionary which decides which parameters of the model will
  be configurable from the interactive application. Each entry of `params` is a pair of
  `Symbol` to an `AbstractVector`, and provides a range of possible values for the parameter
  named after the given symbol (see example online). Changing a value in the parameter
  slides is only propagated to the actual model after a press of the "update" button.

## Data collection related
* `adata, mdata, when`: Same as the keyword arguments of `Agents.run!`. If either or both
  `adata, mdata` are given, data are collected and stored in the `abmobs`,
  see [`ABMObservable`](@ref). The same keywords provide the data plots
  of [`abmexploration`](@ref). This also adds the button "clear data" which deletes
  previously collected agent and model data by emptying the underlying
  `DataFrames` `adf`/`mdf`. Reset model and clear data are independent processes.

See the documentation string of [`ABMObservable`](@ref) for custom interactive plots.
"""
function abmplot end
"""
    abmplot!(ax::Axis, model::ABM; kwargs...)
See `abmplot`.
"""
function abmplot! end
export abmplot, abmplot!

"""
Helper function to retrieve the automatically generated `ABMPlot` type from the
`AgentsVisualizations` extension.
Returns `nothing` if `AgentsVisualizations` was not loaded.
"""
function get_ABMPlot_type()
  AgentsVisualizations = Base.get_extension(Agents, :AgentsVisualizations)
  isnothing(AgentsVisualizations) && return nothing
  return AgentsVisualizations._ABMPlot
end

"""
    add_interaction!(ax)
    add_interaction!(ax, p::_ABMPlot)

Adds model control buttons and parameter sliders according to the plotting parameters 
`add_controls` (if true) and `params` (if not empty).
Buttons and sliders are placed next to each other in a new layout position below the 
position of `ax`.
"""
function add_interaction! end
export add_interaction!

"""
    ABMObservable(model; adata, mdata, when) → abmobs

`abmobs` contains all information necessary to step an agent based model interactively.
It is also returned by [`abmplot`](@ref).

Calling `Agents.step!(abmobs, n)` will step the model for `n` using the provided
`agent_step!, model_step!` cotained in the model as in [`Agents.step!`](@ref).

The fields `abmobs.model, abmobs.adf, abmobs.mdf` are _observables_ that contain
the [`AgentBasedModel`](@ref), and the agent and model dataframes with collected data.
Data are collected as described in [`Agents.run!`](@ref) using the `adata, mdata, when`
keywords. All three observables are updated on stepping (when it makes sense).
The field `abmobs.s` is also an observable containing the current step number.

All plotting and interactivity should be defined by `lift`ing these observables.
"""
struct ABMObservable{M, AS, MS, AD, MD, ADF, MDF, W, S}
    model::M # Observable{AgentBasedModel}
    agent_step!::AS
    model_step!::MS
    adata::AD
    mdata::MD
    adf::ADF # this is `nothing` or `Observable`
    mdf::MDF # this is `nothing` or `Observable`
    s::S # Observable{Int}
    when::W
end
export ABMObservable

"""
    abmexploration(model::ABM; alabels, mlabels, kwargs...)

Open an interactive application for exploring an agent based model and
the impact of changing parameters on the time evolution. Requires `Agents`.

The application evolves an ABM interactively and plots its evolution, while allowing
changing any of the model parameters interactively and also showing the evolution of
collected data over time (if any are asked for, see below).
The agent based model is plotted and animated exactly as in [`abmplot`](@ref),
and the `model` argument as well as splatted `kwargs` are propagated there as-is.
This convencience function *only works for aggregated agent data*.

Calling `abmexploration` returns: `fig::Figure, abmobs::ABMObservable`. So you can save
and/or further modify the figure and it is also possible to access the collected data
(if any) via the `ABMObservable`.

Clicking the "reset" button will add a red vertical line to the data plots for visual
guidance.

## Keywords arguments (in addition to those in `abmplot`)
* `alabels, mlabels`: If data are collected from agents or the model with `adata, mdata`,
  the corresponding plots' y-labels are automatically named after the collected data.
  It is also possible to provide `alabels, mlabels` (vectors of strings with exactly same
  length as `adata, mdata`), and these labels will be used instead.
* `figure = NamedTuple()`: Keywords to customize the created Figure.
* `axis = NamedTuple()`: Keywords to customize the created Axis.
* `plotkwargs = NamedTuple()`: Keywords to customize the styling of the resulting
  [`scatterlines`](https://makie.juliaplots.org/dev/examples/plotting_functions/scatterlines/index.html) plots.
"""
function abmexploration end
export abmexploration

"""
    abmvideo(file, model; kwargs...)

This function exports the animated time evolution of an agent based model into a video
saved at given path `file`, by recording the behavior of the interactive version of
[`abmplot`](@ref) (without sliders).
The plotting is identical as in [`abmplot`](@ref) and applicable keywords are propagated.

## Keywords
* `spf = 1`: Steps-per-frame, i.e. how many times to step the model before recording a new
  frame.
* `framerate = 30`: The frame rate of the exported video.
* `frames = 300`: How many frames to record in total, including the starting frame.
* `title = ""`: The title of the figure.
* `showstep = true`: If current step should be shown in title.
* `figure = NamedTuple()`: Figure related keywords (e.g. resolution, backgroundcolor).
* `axis = NamedTuple()`: Axis related keywords (e.g. aspect).
* `recordkwargs = NamedTuple()`: Keyword arguments given to `Makie.record`.
  You can use `(compression = 1, profile = "high")` for a higher quality output,
  and prefer the `CairoMakie` backend.
  (compression 0 results in videos that are not playable by some software)
* `kwargs...`: All other keywords are propagated to [`abmplot`](@ref).
"""
function abmvideo end
export abmvideo

"""
    agent2string(agent::A)
Convert agent data into a string which is used to display all agent variables and their
values in the tooltip on mouse hover. Concatenates strings if there are multiple agents
at one position.
Custom tooltips for agents can be implemented by adding a specialised method
for `agent2string`.

Example:
```julia
function Agents.agent2string(agent::SpecialAgent)
    \"\"\"
    ✨ SpecialAgent ✨
    ID = \$(agent.id)
    Main weapon = \$(agent.charisma)
    Side weapon = \$(agent.pistol)
    \"\"\"
end
```
"""
function agent2string end

"""
    translate_polygon(p::Polygon, point)
Translate given polygon by given `point`.
"""
function translate_polygon end
"""
    rotate_polygon(p::Polygon, θ)
Rotate given polygon counter-clockwise by `θ` (in radians).
"""
function rotate_polygon end
"""
    scale_polygon(p::Polygon, s)
Scale given polygon by `s`, assuming polygon's center of reference is the origin.
"""
function scale_polygon end
export translate_polygon, scale_polygon, rotate_polygon

############################################################################################
## Visualization API
############################################################################################

"""
    check_space_visualization_API(model::ABM)

Checks whether all the necessary method extensions indicated in 
[`space-visualization-API.jl`](../ext/AgentsVisualizations/space-visualization-API.jl) 
have been defined.
"""
function check_space_visualization_API end

## Required

"""
    agents_space_dimensionality(space::S) where {S<:Agents.AbstractSpace}

Return dimensionality of given model space.
"""
function agents_space_dimensionality end

"""
    get_axis_limits!(model::ABM{S}) where {S<:Agents.AbstractSpace}

Return appropriate axis limits for given model.
Return `nothing, nothing` if you want to disable this.
"""
function get_axis_limits! end

"""
    agentsplot!(ax, model::ABM{S}, p::_ABMPlot) where {S<:Agents.AbstractSpace}

Plot agents at their positions.
"""
function agentsplot! end

## Preplots

"""
    spaceplot!(ax, model::ABM{S}; preplotkwargs...) where {S<:Agents.AbstractSpace}

Create a space-dependent preplot.
"""
function spaceplot! end

function static_preplot! end

## Lifting

"""
    abmplot_heatobs(model::ABM{S}, heatarray)
"""
function abmplot_heatobs end
"""
    abmplot_ids(model::ABM{S})
"""
function abmplot_ids end
"""
    abmplot_pos(model::ABM{S}, offset, ids)
"""
function abmplot_pos end
"""
  abmplot_colors(model::ABM{S}, ac, ids)
  abmplot_colors(model::ABM{S}, ac::Function, ids)
"""
function abmplot_colors end
"""
    abmplot_marker(model::ABM{S}, used_poly, am, pos, ids)
    abmplot_marker(model::ABM{S}, used_poly, am::Function, pos, ids)
"""
function abmplot_marker end
"""
    abmplot_markersizes(model::ABM{S}, as, ids)
    abmplot_markersizes(model::ABM{S}, as::Function, ids)
"""
function abmplot_markersizes end

## Inspection

"""
    convert_mouse_position(::S, pos)

Convert a `Point2f`/`Point3f` position in the Makie figure to its corresponding position in 
the given space `S`.
"""
function convert_mouse_position end

"""
    ids_to_inspect(model::ABM{S}, pos)
"""
function ids_to_inspect end

# Some cheat functions that only exist so that we can have
# a conditional dependency on OSMMakie and GraphMakie
function osmplot! end
function graphplot! end

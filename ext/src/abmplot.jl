include("model_observable.jl")
export abmplot, abmplot!

"""
    abmplot(model::ABM; kwargs...) → fig, ax, abmobs
    abmplot!(ax::Axis/Axis3, model::ABM; kwargs...) → abmobs

Plot an agent based model by plotting each individual agent as a marker and using
the agent's position field as its location on the plot. The same function is used
to make custom composite plots and interactive applications for the model evolution
using the returned `abmobs`. `abmplot` is also used to launch interactive GUIs for
evolving agent based models, see "Interactivity" below.

Requires `Agents`. See also [`abmvideo`](@ref) and [`abmexploration`](@ref).

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
  Notice that for 2D models, `am` can be/return a `Polygon` instance, which plots each agent
  as an arbitrary polygon. It is assumed that the origin (0, 0) is the agent's position when
  creating the polygon. In this case, the keyword `as` is meaningless, as each polygon has
  its own size. Use the functions `scale, rotate2D` to transform this polygon.

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

The stand-alone function `abmplot` also takes two optional `NamedTuple`s named `figure` and
`axis` which can be used to change the automatically created `Figure` and `Axis` objects.

# Interactivity

## Evolution related
* `agent_step!, model_step! = Agents.dummystep`: Stepping functions to pass to
  [`ABMObservable`](@ref) which itself passes to `Agents.step!`.
* `add_controls::Bool`: If `true`, `abmplot` switches to "interactive application" mode.
  This is by default `true` if either `agent_step!` or `model_step!` keywords are provided.
  These stepping functions are used to evolve the model interactively using `Agents.step!`.
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
function abmplot(model::Agents.ABM;
        figure = NamedTuple(),
        axis = NamedTuple(),
        kwargs...)
    fig = Figure(; figure...)
    ax = fig[1,1][1,1] = agents_space_dimensionality(model) == 3 ?
        Axis3(fig; axis...) : Axis(fig; axis...)
    abmobs = abmplot!(ax, model; kwargs...)

    return fig, ax, abmobs
end

function abmplot!(ax, model::Agents.ABM;
        # These keywords are given to `ABMObservable`
        agent_step! = Agents.dummystep,
        model_step! = Agents.dummystep,
        adata = nothing,
        mdata = nothing,
        when = true,
        kwargs...)
    abmobs = ABMObservable(model; agent_step!, model_step!, adata, mdata, when)
    abmplot!(ax, abmobs; kwargs...)

    return abmobs
end

"""
    abmplot(abmobs::ABMObservable; kwargs...) → fig, ax, abmobs
    abmplot!(ax::Axis/Axis3, abmobs::ABMObservable; kwargs...) → abmobs

Same functionality as `abmplot(model; kwargs...)`/`abmplot!(ax, model; kwargs...)`
but allows to link an already existing `ABMObservable` to the created plots.
"""

function abmplot(abmobs::ABMObservable;
        figure = NamedTuple(),
        axis = NamedTuple(),
        kwargs...)
    fig = Figure(; figure...)
    ax = fig[1,1][1,1] = agents_space_dimensionality(abmobs.model[]) == 3 ?
        Axis3(fig; axis...) : Axis(fig; axis...)
    abmplot!(ax, abmobs; kwargs...)

    return fig, ax, abmobs
end

function abmplot!(ax, abmobs::ABMObservable;
        # These keywords are propagated to the _ABMPlot recipe
        add_controls = _default_add_controls(abmobs.agent_step!, abmobs.model_step!),
        enable_inspection = add_controls,
        kwargs...)
    _abmplot!(ax, abmobs; ax, add_controls, kwargs...)

    # Model inspection on mouse hover
    enable_inspection && DataInspector(ax.parent)

    return abmobs
end

"""
    _abmplot(model::ABM; kwargs...) → fig, ax, abmplot_object
    _abmplot!(model::ABM; ax::Axis/Axis3, kwargs...) → abmplot_object

This is the internal recipe for creating an `_ABMPlot`.
"""
@recipe(_ABMPlot, abmobs) do scene
    Theme(
        # insert InteractiveDynamics theme here?
    )
    Attributes(
        # Axis
        # ax is currently necessary to have a reference to the parent Axis. This is needed
        # for optional Colorbar of heatmap and optional buttons/sliders.
        # Makie's recipe system still works on the old system of Scenes which have no
        # concept of a parent Axis. Makie devs plan to enable this in the future. Until then
        # we will have to work around it with this "little hack".
        ax = nothing,

        # Agent
        ac = JULIADYNAMICS_COLORS[1],
        as = 15,
        am = :circle,
        offset = nothing,
        scatterkwargs = NamedTuple(),
        osmkwargs = NamedTuple(),
        graphplotkwargs = NamedTuple(),

        # Preplot
        heatarray = nothing,
        heatkwargs = NamedTuple(),
        add_colorbar = true,
        static_preplot! = nothing,

        # Interactive application
        add_controls = false,
        # Add parameter sliders if params are provided
        params = Dict(),
        # Animation evolution speed
        spu = 1:50,

        # Internal Attributes necessary for inspection, controls, etc. to work
        _used_poly = false,
    )
end

function _default_add_controls(agent_step!, model_step!)
    (agent_step! != Agents.dummystep) || (model_step! != Agents.dummystep)
end

const SUPPORTED_SPACES = Union{
    Agents.GridSpace,
    Agents.GridSpaceSingle,
    Agents.ContinuousSpace,
    Agents.OpenStreetMapSpace,
    Agents.GraphSpace,
}



function Makie.plot!(abmplot::_ABMPlot)
    model = abmplot.abmobs[].model[]
    if !(model.space isa SUPPORTED_SPACES)
        error("Space type $(typeof(model.space)) is not supported for plotting.")
    end
    ax = abmplot.ax[]
    isnothing(ax.aspect[]) && (ax.aspect = DataAspect())
    if !(model.space isa Agents.GraphSpace)
        set_axis_limits!(ax, model)
    end
    fig = ax.parent

    # Following attributes are all lifted from the recipe observables (specifically,
    # the model), see lifting.jl for source code.
    pos, color, marker, markersize, heatobs =
        lift_attributes(abmplot.abmobs[].model, abmplot.ac, abmplot.as, abmplot.am,
            abmplot.offset, abmplot.heatarray, abmplot._used_poly)

    # OpenStreetMapSpace preplot
    if model.space isa Agents.OpenStreetMapSpace
        osm_plot = osmplot!(abmplot.ax[], model.space.map;
            graphplotkwargs = (; arrow_show = false), abmplot.osmkwargs...
        )
        osm_plot.plots[1].plots[1].plots[1].inspectable[] = false
        osm_plot.plots[1].plots[3].inspectable[] = false
    end

    # Heatmap
    if !isnothing(heatobs[])
        if !(Agents.abmspace(model) isa Agents.ContinuousSpace)
            hmap = heatmap!(abmplot, heatobs;
                colormap = JULIADYNAMICS_CMAP, abmplot.heatkwargs...
            )
        else # need special version for continuous space
            nbinx, nbiny = size(heatobs[])
            extx, exty = Agents.abmspace(model).extent
            coordx = range(0, extx; length = nbinx)
            coordy = range(0, exty; length = nbiny)
            hmap = heatmap!(abmplot, coordx, coordy, heatobs;
                colormap = JULIADYNAMICS_CMAP, abmplot.heatkwargs...
            )
        end

        if abmplot.add_colorbar[]
            Colorbar(fig[1, 1][1, 2], hmap, width = 20)
            # TODO: Set colorbar to be "glued" to axis
            # Problem with the following code, which comes from the tutorial
            # https://makie.juliaplots.org/stable/tutorials/aspect-tutorial/ ,
            # is that it only works for axis that have 1:1 aspect ratio...
            # rowsize!(fig[1, 1].layout, 1, ax.scene.px_area[].widths[2])
            # colsize!(fig[1, 1].layout, 1, Aspect(1, 1.0))
        end
    end

    # Static preplot
    if !isnothing(abmplot.static_preplot![])
        abmplot.static_preplot![](ax, model)
    end

    # Dispatch on type of agent positions
    T = typeof(pos[])
    if T<:Nothing # GraphSpace
        hidedecorations!(ax)
        ec = get(abmplot.graphplotkwargs, :edge_color, Observable(:black))
        edge_color = @lift(abmplot_edge_color($(abmplot.abmobs[].model), $ec))
        ew = get(abmplot.graphplotkwargs, :edge_width, Observable(1))
        edge_width = @lift(abmplot_edge_width($(abmplot.abmobs[].model), $ew))
        graphplot!(abmplot, model.space.graph;
            node_color = color, node_marker = marker, node_size = markersize,
            abmplot.graphplotkwargs..., # must come first to not overwrite lifted kwargs
            edge_color, edge_width)
    elseif T<:Vector{Point2f} # 2d space
        if typeof(marker[])<:Vector{<:Polygon{2}}
            poly_plot = poly!(abmplot, marker; color, abmplot.scatterkwargs...)
            poly_plot.inspectable[] = false # disable inspection for poly until fixed
        else
            scatter!(abmplot, pos; color, marker, markersize, abmplot.scatterkwargs...)
        end
    elseif T<:Vector{Point3f} # 3d space
        marker[] == :circle && (marker = Sphere(Point3f(0), 1))
        meshscatter!(abmplot, pos; color, marker, markersize, abmplot.scatterkwargs...)
    else
        @warn("Unknown agent position type: $(T). Skipping plotting agents.")
    end

    # Model controls, parameter sliders
    abmplot.stepclick, abmplot.resetclick = add_interaction!(fig, ax, abmplot)

    return abmplot
end

"Plot space and/or set axis limits."
function set_axis_limits!(ax, model)
    if model.space isa Agents.OpenStreetMapSpace
        o = [Inf, Inf]
        e = [-Inf, -Inf]
        for i ∈ Agents.positions(model)
            x, y = Agents.OSM.lonlat(i, model)
            o[1] = min(x, o[1]); o[2] = min(y, o[2])
            e[1] = max(x, e[1]); e[2] = max(y, e[2])
        end
    elseif model.space isa Agents.ContinuousSpace
        e = model.space.extent
        o = zero.(e)
    elseif model.space isa Agents.AbstractGridSpace
        e = size(model.space) .+ 0.5
        o = zero.(e) .+ 0.5
    end
    xlims!(ax, o[1], e[1])
    ylims!(ax, o[2], e[2])
    length(o) == 3 && zlims!(ax, o[3], e[3])
    return o, e
end

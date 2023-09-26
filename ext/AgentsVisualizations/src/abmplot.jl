include("model_observable.jl")

function Agents.abmplot(model::Agents.ABM;
    figure=NamedTuple(),
    axis=NamedTuple(),
    kwargs...)
    fig = Figure(; figure...)
    ax = fig[1, 1][1, 1] = agents_space_dimensionality(model) == 3 ?
                           Axis3(fig; axis...) : Axis(fig; axis...)
    abmobs = abmplot!(ax, model; kwargs...)

    return fig, ax, abmobs
end

function Agents.abmplot!(ax, model::Agents.ABM;
    # These keywords are given to `ABMObservable`
    agent_step! = Agents.dummystep,
    model_step! = Agents.dummystep,
    adata=nothing,
    mdata=nothing,
    when=true,
    kwargs...)
    if agent_step! == Agents.dummystep && model_step! == Agents.dummystep
        agent_step! = Agents.agent_step_field(model)
        model_step! = Agents.model_step_field(model)
    else
        @warn "some warning"
    end
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
function Agents.abmplot(abmobs::ABMObservable;
    axis=NamedTuple(),
    add_controls=false,
    figure=add_controls ? (resolution=(800, 600),) : (resolution=(800, 800),),
    kwargs...)
    fig = Figure(; figure...)
    ax = fig[1, 1][1, 1] = agents_space_dimensionality(abmobs.model[]) == 3 ?
                           Axis3(fig; axis...) : Axis(fig; axis...)
    abmplot!(ax, abmobs; kwargs...)

    return fig, ax, abmobs
end

function Agents.abmplot!(ax, abmobs::ABMObservable;
    # These keywords are propagated to the _ABMPlot recipe
    add_controls=_default_add_controls(abmobs.agent_step!, abmobs.model_step!),
    enable_inspection=add_controls,
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
    # TODO: insert JuliaDynamics theme here?
    )
    Attributes(
        # Axis
        # ax is currently necessary to have a reference to the parent Axis. This is needed
        # for optional Colorbar of heatmap and optional buttons/sliders.
        # Makie's recipe system still works on the old system of Scenes which have no
        # concept of a parent Axis. Makie devs plan to enable this in the future. Until then
        # we will have to work around it with this "little hack".
        ax=nothing,

        # Agent
        ac=JULIADYNAMICS_COLORS[1],
        as=15,
        am=:circle,
        offset=nothing,
        scatterkwargs=NamedTuple(),
        osmkwargs=NamedTuple(),
        graphplotkwargs=NamedTuple(),

        # Preplot
        heatarray=nothing,
        heatkwargs=NamedTuple(),
        add_colorbar=true,
        (static_preplot!)=nothing,
        adjust_aspect=true,

        # Interactive application
        add_controls=false,
        # Add parameter sliders if params are provided
        params=Dict(),
        # Animation evolution speed
        spu=1:50,

        # Internal Attributes necessary for inspection, controls, etc. to work
        _used_poly=false,
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
    if !(abmspace(model) isa SUPPORTED_SPACES)
        error("Space type $(typeof(abmspace(model))) is not supported for plotting.")
    end
    ax = abmplot.ax[]
    abmplot.adjust_aspect[] && (ax.aspect = DataAspect())
    if !(abmspace(model) isa Agents.GraphSpace)
        set_axis_limits!(ax, model)
    end
    fig = ax.parent

    # Following attributes are all lifted from the recipe observables (specifically,
    # the model), see lifting.jl for source code.
    pos, color, marker, markersize, heatobs =
        lift_attributes(abmplot.abmobs[].model, abmplot.ac, abmplot.as, abmplot.am,
            abmplot.offset, abmplot.heatarray, abmplot._used_poly)

    # OpenStreetMapSpace preplot
    if abmspace(model) isa Agents.OpenStreetMapSpace
        Agents.agents_osmplot!(abmplot.ax[], model; abmplot.osmkwargs...)
    end

    # Heatmap
    if !isnothing(heatobs[])
        if !(Agents.abmspace(model) isa Agents.ContinuousSpace)
            hmap = heatmap!(abmplot, heatobs;
                colormap=JULIADYNAMICS_CMAP, abmplot.heatkwargs...
            )
        else # need special version for continuous space
            nbinx, nbiny = size(heatobs[])
            extx, exty = Agents.abmspace(model).extent
            coordx = range(0, extx; length=nbinx)
            coordy = range(0, exty; length=nbiny)
            hmap = heatmap!(abmplot, coordx, coordy, heatobs;
                colormap=JULIADYNAMICS_CMAP, abmplot.heatkwargs...
            )
        end

        if abmplot.add_colorbar[]
            Colorbar(fig[1, 1][1, 2], hmap, width=20)
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
    if T <: Nothing # GraphSpace
        hidedecorations!(ax)
        ec = get(abmplot.graphplotkwargs, :edge_color, Observable(:black))
        edge_color = @lift(abmplot_edge_color($(abmplot.abmobs[].model), $ec))
        ew = get(abmplot.graphplotkwargs, :edge_width, Observable(1))
        edge_width = @lift(abmplot_edge_width($(abmplot.abmobs[].model), $ew))
        Agents.agents_graphplot!(abmplot, abmspace(model).graph;
            node_color=color, node_marker=marker, node_size=markersize,
            abmplot.graphplotkwargs, # must come first to not overwrite lifted kwargs
            edge_color, edge_width)
    elseif T <: Vector{Point2f} # 2d space
        if typeof(marker[]) <: Vector{<:Makie.Polygon{2}}
            poly_plot = poly!(abmplot, marker; color, abmplot.scatterkwargs...)
            poly_plot.inspectable[] = false # disable inspection for poly until fixed
        else
            scatter!(abmplot, pos; color, marker, markersize, abmplot.scatterkwargs...)
        end
    elseif T <: Vector{Point3f} # 3d space
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
    if abmspace(model) isa Agents.OpenStreetMapSpace
        o = [Inf, Inf]
        e = [-Inf, -Inf]
        for i ∈ Agents.positions(model)
            x, y = Agents.OSM.lonlat(i, model)
            o[1] = min(x, o[1])
            o[2] = min(y, o[2])
            e[1] = max(x, e[1])
            e[2] = max(y, e[2])
        end
    elseif abmspace(model) isa Agents.ContinuousSpace
        e = abmspace(model).extent
        o = zero.(e)
    elseif abmspace(model) isa Agents.AbstractGridSpace
        e = size(abmspace(model)) .+ 0.5
        o = zero.(e) .+ 0.5
    end
    xlims!(ax, o[1], e[1])
    ylims!(ax, o[2], e[2])
    length(o) == 3 && zlims!(ax, o[3], e[3])
    return o, e
end

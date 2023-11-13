function Agents.abmplot(model::Agents.ABM;
    figure=NamedTuple(),
    axis=NamedTuple(),
    warn_deprecation = true,
    kwargs...)
    fig = Figure(; figure...)
    ax = fig[1, 1][1, 1] = agents_space_dimensionality(model) == 3 ?
                           Axis3(fig; axis...) : Axis(fig; axis...)
    abmobs = abmplot!(ax, model; warn_deprecation = warn_deprecation, kwargs...)

    return fig, ax, abmobs
end

function Agents.abmplot!(ax, model::Agents.ABM;
    # These keywords are given to `ABMObservable`
    agent_step! = Agents.dummystep,
    model_step! = Agents.dummystep,
    adata=nothing,
    mdata=nothing,
    when=true,
    warn_deprecation = true,
    kwargs...)
    if agent_step! == Agents.dummystep && model_step! == Agents.dummystep
        agent_step! = Agents.agent_step_field(model)
        model_step! = Agents.model_step_field(model)
    elseif warn_deprecation
        @warn "Passing agent_step! and model_step! to abmplot! is deprecated. 
          These functions should be already contained inside the model instance."
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
        preplotkwargs=NamedTuple(),
        graphplotkwargs=NamedTuple(),

        # Preplot
        heatarray=nothing,
        heatkwargs=NamedTuple(),
        add_colorbar=true,
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

const DEFAULT_SPACES = Union{
    Agents.GridSpace,
    Agents.GridSpaceSingle,
    Agents.ContinuousSpace,
    Agents.OpenStreetMapSpace,
    Agents.GraphSpace,
}

function Makie.plot!(abmplot::_ABMPlot)
    model = abmplot.abmobs[].model[]
    ax = abmplot.ax[]
    !(abmspace(model) isa DEFAULT_SPACES) && custom_space_checker(ax, model, abmplot)
    abmplot.adjust_aspect[] && (ax.aspect = DataAspect())
    set_axis_limits!(ax, model)

    abmplot.pos, abmplot.color, abmplot.marker, abmplot.markersize =
        lift_attributes(abmplot.abmobs[].model, abmplot.ac, abmplot.as, abmplot.am,
            abmplot.offset, abmplot._used_poly)

    preplot!(ax, model; abmplot.preplotkwargs...)
    heatmap!(ax, abmplot)
    static_preplot!(ax, model)
    plot_agents!(abmplot, model)

    # Model controls, parameter sliders
    abmplot.stepclick, abmplot.resetclick = add_interaction!(ax.parent, ax, abmplot)

    return abmplot
end

function lift_attributes(model, ac, as, am, offset, used_poly)
    ids = @lift(abmplot_ids($model))
    pos = @lift(abmplot_pos($model, $offset, $ids))
    color = @lift(abmplot_colors($model, $ac, $ids))
    marker = @lift(abmplot_marker($model, used_poly, $am, $pos, $ids))
    markersize = @lift(abmplot_markersizes($model, $as, $ids))

    return pos, color, marker, markersize
end

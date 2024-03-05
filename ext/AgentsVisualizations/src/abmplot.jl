function Agents.abmplot(model::ABM;
        figure=NamedTuple(),
        axis=NamedTuple(),
        warn_deprecation = true,
        kwargs...
    )
    fig = Figure(; figure...)
    ax = fig[1, 1][1, 1] = axistype(model)(fig; axis...)
    abmobs = abmplot!(ax, model; warn_deprecation = warn_deprecation, kwargs...)

    return fig, ax, abmobs
end

function axistype(model::ABM)
    D = agents_space_dimensionality(model)
    D == 3 && return Axis3
    D == 2 && return Axis
    @error """Cannot determine axis type for space dimensionality $D.
    Please report this as an issue at the Agents.jl repository."""
end

function Agents.abmplot!(ax, model::ABM;
        # These keywords are given to `ABMObservable`
        agent_step! = Agents.dummystep,
        model_step! = Agents.dummystep,
        adata=nothing,
        mdata=nothing,
        when=true,
        warn_deprecation = true,
        kwargs...
    )
    if agent_step! == Agents.dummystep && model_step! == Agents.dummystep
        agent_step! = Agents.agent_step_field(model)
        model_step! = Agents.model_step_field(model)
    elseif warn_deprecation
        @warn "Passing agent_step! and model_step! to abmplot! is deprecated. 
          These functions should be already contained inside the model instance." maxlog=1
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
        kwargs...
    )
    fig = Figure(; figure...)
    ax = fig[1, 1][1, 1] = axistype(abmobs.model[])(fig; axis...)
    abmplot!(ax, abmobs; kwargs...)

    return fig, ax, abmobs
end

function Agents.abmplot!(ax, abmobs::ABMObservable;
        # These keywords are propagated to the _ABMPlot recipe
        add_controls = _default_add_controls(abmobs.agent_step!, abmobs.model_step!),
        enable_inspection = add_controls,
        enable_space_checks = true,
        kwargs...
    )
    if any(x -> x in keys(kwargs), [:as, :am, :ac])
        @warn "Keywords `as, am, ac` has been deprecated in favor of 
          `agent_size, agent_marker, agent_color`" maxlog=1
    end
    if enable_space_checks
        if has_custom_space(abmobs.model[])
            Agents.check_space_visualization_API(abmobs.model[])
        end
    end
    _abmplot!(ax, abmobs; ax, add_controls, kwargs...)

    # Model inspection on mouse hover
    enable_inspection && DataInspector(ax.parent)

    return abmobs
end

_default_add_controls(as, ms) = (as != Agents.dummystep) || (ms != Agents.dummystep)

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
        spaceplotkwargs = NamedTuple(),
        agentsplotkwargs = NamedTuple(),

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

function Makie.plot!(p::_ABMPlot)
    model = p.abmobs[].model[]
    ax = p.ax[]
    p.adjust_aspect[] && (ax.aspect = DataAspect())
    set_axis_limits!(ax, model)

    p.pos, p.color, p.marker, p.markersize = 
        lift_attributes(p.abmobs[].model, p.ac, p.as, p.am, p.offset)

    # gracefully handle deprecations of old plot kwargs
    merge_spaceplotkwargs!(p)
    merge_agentsplotkwargs!(p)

    spaceplot!(ax, p; p.spaceplotkwargs...)
    heatmap!(ax, p)
    static_preplot!(ax, p)
    agentsplot!(ax, p)

    p.stepclick, p.resetclick = add_interaction!(ax, p)

    return p
end

function set_axis_limits!(ax::Axis, model::ABM)
    o, e = get_axis_limits(model)
    any(isnothing, (o, e)) && return nothing
    xlims!(ax, o[1], e[1])
    ylims!(ax, o[2], e[2])
    return o, e
end

function set_axis_limits!(ax::Axis3, model::ABM)
    o, e = get_axis_limits(model)
    any(isnothing, (o, e)) && return nothing
    xlims!(ax, o[1], e[1])
    ylims!(ax, o[2], e[2])
    zlims!(ax, o[3], e[3])
    return o, e
end

function heatmap!(ax, p::_ABMPlot)
    heatobs = @lift(abmplot_heatobs($(p.abmobs[].model), p.heatarray[]))
    isnothing(heatobs[]) && return nothing
    hmap = Makie.heatmap!(p, heatobs; 
        colormap=JULIADYNAMICS_CMAP, p.heatkwargs...)
    p.add_colorbar[] && Colorbar(ax.parent[1, 1][1, 2], hmap, width=20)
    # TODO: Set colorbar to be "glued" to axis
    # Problem with the following code, which comes from the tutorial
    # https://makie.juliaplots.org/stable/tutorials/aspect-tutorial/ ,
    # is that it only works for axis that have 1:1 aspect ratio...
    # rowsize!(fig[1, 1].layout, 1, ax.scene.px_area[].widths[2])
    # colsize!(fig[1, 1].layout, 1, Aspect(1, 1.0))
    return hmap
end

function lift_attributes(model, ac, as, am, offset)
    pos = @lift(abmplot_pos($model, $offset))
    color = @lift(abmplot_colors($model, $ac))
    marker = @lift(abmplot_markers($model, $am, $pos))
    markersize = @lift(abmplot_markersizes($model, $as))

    return pos, color, marker, markersize
end

const ABMP{S} = _ABMPlot{<:Tuple{<:ABMObservable{<:Observable{<:ABM{<:S}}}}}

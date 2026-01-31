# Convenience functions that propagate stuff to the main function
function Agents.abmplot(either;
        # These keywords are about the `ABM`
        adata=nothing, mdata=nothing, when=true,

        axis=NamedTuple(),
        add_controls=false,
        figure=NamedTuple(),
        kwargs...
    )
    resolution = add_controls ? (800, 600) : (800, 800)
    fig = Figure(; resolution, figure...)
    abmobs = if either <: ABM
        ABMObservable(model; adata, mdata, when)
    else
        either
    end
    ax = axistype(abmobs.model[])(fig[1, 1][1, 1]; axis...)
    abmplot!(ax, abmobs; kwargs...)
    return fig, ax, abmobs
end

function Agents.abmplot!(ax, model::ABM;
        # These keywords are about the `ABM`
        adata=nothing, mdata=nothing, when=true,
        # While all the rest are plotting related:
        kwargs...
    )
    abmobs = ABMObservable(model; adata, mdata, when)
    abmplot!(ax, abmobs; kwargs...) # MAIN function
    return abmobs
end

function axistype(model::ABM)
    D = space_axis_dimensionality(model)
    D == 3 && return Axis3
    D == 2 && return Axis
    @error """Invalid axis dimensionality $(D)."""
end

###########################################################################################
# Main plotting function
###########################################################################################
function Agents.abmplot!(
        ax::Union{Axis, Axis3}, abmobs::ABMObservable;

        # Agent
        agent_color=JULIADYNAMICS_COLORS[1],
        agent_size=15,
        agent_marker=:circle,
        offset=nothing,
        agentsplotkwargs = NamedTuple(),

        # Preplot
        heatarray=nothing,
        heatkwargs=NamedTuple(),
        static_preplot! = (args...,) -> nothing,
        add_colorbar=true,
        adjust_aspect=true,
        enable_space_checks = true,
        spaceplotkwargs = NamedTuple(),

        # Interactivity
        add_controls=false,
        params=Dict(),
        add_controls = !isempty(params),
        dt=nothing, # animation evolution speed
        enable_inspection = add_controls,
        _used_poly=false,

    )

    model = abmobs.model[]

    if enable_space_checks
        if has_custom_space(model)
            Agents.check_space_visualization_API(model)
        end
    end

    if adjust_aspect
        if ax isa Axis
            ax.aspect = DataAspect()
        elseif ax isa Axis3
            ax.aspect = :data # is this up-to-date?
        end
    end
    set_axis_limits!(ax, model)

    # These are all observables:
    pos, color, marker, markersize =
        lift_attributes(model, agent_color, agent_size, agent_marker, offset)

    spaceplot!(ax, model; spaceplotkwargs...)
    heatmap!(ax, abmobs, heatarray, add_colorbar, heatkwargs)
    static_preplot!(ax, abmobs)
    # XXX I STOPPED HERE
    agentsplot!(ax, model, pos, color, marker, markersize, agentsplotkwargs)

    add_controls && add_interaction!(ax, abmobs, params, dt)

    # Model inspection on mouse hover
    # TODO: Currently disabled as it relied on old recipe system
    # enable_inspection && DataInspector(ax.parent)

    return abmobs
end

_default_add_controls(as, ms) = true

function Makie.plot!(p::_ABMPlot)

end

function set_axis_limits!(ax::Axis, model::ABM)
    o, e = space_axis_limits(model)
    any(isnothing, (o, e)) && return nothing
    xlims!(ax, o[1], e[1])
    ylims!(ax, o[2], e[2])
    return o, e
end

function set_axis_limits!(ax::Axis3, model::ABM)
    o, e = space_axis_limits(model)
    any(isnothing, (o, e)) && return nothing
    xlims!(ax, o[1], e[1])
    ylims!(ax, o[2], e[2])
    zlims!(ax, o[3], e[3])
    return o, e
end

function heatmap!(ax, abmobs::ABMObservable, heatarray, add_colorbar, heatkwargs)
    heatobs = @lift(abmplot_heatobs($(abmobs.model), heatarray))
    isnothing(heatobs[]) && return nothing
    hmap = Makie.heatmap!(
        p, heatobs;
        colormap=JULIADYNAMICS_CMAP, heatkwargs
    )
    add_colorbar && Colorbar(ax.parent[1, 1][1, 2], hmap, width=20)
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

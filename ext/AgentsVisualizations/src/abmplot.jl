# Convenience functions that propagate stuff to the main function
function Agents.abmplot(either;
        # These keywords are about the `ABM`
        adata=nothing, mdata=nothing, when=true,

        axis=NamedTuple(),
        add_controls=false,
        figure=NamedTuple(),
        kwargs...
    )
    size = add_controls ? (800, 600) : (800, 800)
    fig = Figure(; size, figure...)
    abmobs = if either isa ABM
        ABMObservable(either; adata, mdata, when)
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
        preplot! = (args...,) -> nothing,
        add_colorbar=true,
        adjust_aspect=true,
        spaceplotkwargs = NamedTuple(),

        # Interactivity
        params=Dict(),
        add_controls = !isempty(params),
        dt=nothing, # animation evolution speed
        enable_inspection = add_controls,
    )

    model = abmobs.model[]

    if adjust_aspect
        if ax isa Axis
            ax.aspect = DataAspect()
        elseif ax isa Axis3
            ax.aspect = :data # is this up-to-date?
        end
    end
    ax.limits = space_axis_limits(model)

    # These are all observables:
    pos, color, marker, markersize = lift_attributes(
        abmobs.model, agent_color, agent_size, agent_marker, offset
    )

    # heatmap and other plots
    if !isnothing(heatarray)
        abmheatmap!(ax, abmobs, abmspace(model), heatarray, heatkwargs)
        add_colorbar && Colorbar(ax.parent[1, 1][1, 2], hmap, width=20)
        # TODO: Set colorbar to be "glued" to axis
        # Problem with the following code, which comes from the tutorial
        # https://makie.juliaplots.org/stable/tutorials/aspect-tutorial/ ,
        # is that it only works for axis that have 1:1 aspect ratio...
        # rowsize!(fig[1, 1].layout, 1, ax.scene.px_area[].widths[2])
        # colsize!(fig[1, 1].layout, 1, Aspect(1, 1.0))
    end
    spaceplot!(ax, model; spaceplotkwargs...)
    preplot!(ax, abmobs)

    # and the agent plot
    # XXX I STOPPED HERE
    agentsplot!(ax, model, pos, color, marker, markersize, agentsplotkwargs)

    add_controls && add_interaction!(ax, abmobs, params, dt)

    # Model inspection on mouse hover
    # TODO: Currently disabled as it relied on old recipe system
    # enable_inspection && DataInspector(ax.parent)

    return abmobs
end

function lift_attributes(model, ac, as, am, offset)
    pos = lift((x, y) -> abmplot_pos(x, y), model, offset)
    color = lift((x, y) -> abmplot_colors(x, y), model, ac)
    marker = lift((x, y, z) -> abmplot_markers(x, y, z), model, am, pos)
    markersize = lift((x, y) -> abmplot_markersizes(x, y), model, as)
    return pos, color, marker, markersize
end

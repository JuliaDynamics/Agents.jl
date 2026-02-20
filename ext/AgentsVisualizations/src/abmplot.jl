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
    abmplot!(ax, abmobs; add_controls, kwargs...)
    return fig, ax, abmobs
end

function Agents.abmplot!(ax, model::ABM;
        # These keywords are about the `ABM`
        adata = nothing, mdata = nothing, when = true,
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
        colorbar_label = "",
        adjust_aspect=true,
        spaceplotkwargs = NamedTuple(),

        # Interactivity
        params=Dict(),
        add_controls = !isempty(params),
        dt=nothing, # animation evolution speed
        enable_inspection = add_controls,
    )

    if adjust_aspect
        if ax isa Axis
            ax.aspect = DataAspect()
        elseif ax isa Axis3
            ax.aspect = :data # TODO: is this up-to-date?
        end
    end
    modelobs = abmobs.model
    ax.limits = space_axis_limits(modelobs[])

    # other plots
    Agents.spaceplot!(ax, abmspace(modelobs[]); spaceplotkwargs...)
    if !isnothing(heatarray)
        heatobs = @lift(abmplot_heatarray($(modelobs), heatarray))
        abmheatmap!(ax, abmobs, abmspace(modelobs[]), heatobs, heatkwargs)
        add_colorbar && Colorbar(ax.parent[1, 1][1, 2], hmap; width=20, label = colorbar_label)
        # TODO: Set colorbar to be "glued" to axis
        # Problem with the following code, which comes from the tutorial
        # https://makie.juliaplots.org/stable/tutorials/aspect-tutorial/ ,
        # is that it only works for axis that have 1:1 aspect ratio...
        # rowsize!(fig[1, 1].layout, 1, ax.scene.px_area[].widths[2])
        # colsize!(fig[1, 1].layout, 1, Aspect(1, 1.0))
    end
    preplot!(ax, abmobs)

    # and finally the agent plot
    agentsplot!(ax, modelobs, agent_color, agent_size, agent_marker, offset, agentsplotkwargs)

    add_controls && add_interaction!(ax, abmobs, params, dt)

    # Model inspection on mouse hover
    # TODO: Currently disabled as it relied on old recipe system
    # enable_inspection && DataInspector(ax.parent)

    return abmobs
end


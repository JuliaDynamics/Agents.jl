# We need to implement plotting for a `nothing` space,
# so that the data collection GUI can work for it, even if there is
# nothing to plot for the space itself.

Agents.space_axis_limits(::Nothing) = ((nothing, nothing), (nothing, nothing))

function Agents.Agents.agentsplot!(ax::Axis, space::Nothing, pos, color, marker, markersize, agentsplotkwargs)
    s = scatter!(ax, pos)
    s.visible[] = false
    return nothing
end

# just a special case for the `nothing` space
Agents.abmplot_pos(model::ABM{Nothing}, offset) = Point2f[(0.5, 0.5)]

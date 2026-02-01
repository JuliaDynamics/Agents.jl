# We need to implement plotting for a `nothing` space,
# so that the data collection GUI can work for it, even if there is
# nothing to plot for the space itself.

## Required

Agents.space_axis_dimensionality(model::ABM{Nothing}) =
    Agents.space_axis_dimensionality(abmspace(model))
Agents.space_axis_dimensionality(space::Nothing) = 2

Agents.space_axis_limits(model::ABM{Nothing}) = nothing, nothing

function Agents.Agents.agentsplot!(ax::Axis, space::Nothing, pos, color, marker, markersize, agentsplotkwargs)
    s = scatter!(ax, pos)
    s.visible[] = false
    return nothing
end

## Preplots

## Lifting, just a special case for the `nothing` space

Agents.abmplot_pos(model::ABM{Nothing}, offset) = Point2f[(0.5, 0.5)]

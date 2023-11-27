## Required

Agents.agents_space_dimensionality(model::ABM{Nothing}) = 
    Agents.agents_space_dimensionality(abmspace(model))
Agents.agents_space_dimensionality(space::Nothing) = 2

Agents.get_axis_limits(model::ABM{Nothing}) = nothing, nothing

function Agents.agentsplot!(ax::Axis, model::ABM{Nothing}, p::_ABMPlot)
    s = scatter!(p, p.pos)
    s.visible[] = false
    return p
end

## Preplots

## Lifting

Agents.abmplot_pos(model::ABM{Nothing}, offset, ids) = Point2f[(0.5, 0.5)]

## Inspection

Agents.ids_to_inspect(model::ABM{Nothing}, pos) = []

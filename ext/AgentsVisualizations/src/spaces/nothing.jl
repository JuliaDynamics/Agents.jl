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

Agents.abmplot_pos(model::ABM{Nothing}, offset) = Point2f[(0.5, 0.5)]

## Inspection

function Makie.show_data(inspector::DataInspector, 
        p::ABMP{<:Nothing}, idx, source::Scatter)
    pos = source.converted[1][][idx]
    proj_pos = Makie.shift_project(Makie.parent_scene(p), p, to_ndim(Point3f, pos, 0))
    Makie.update_tooltip_alignment!(inspector, proj_pos)

    model = p.abmobs[].model[]
    a = inspector.plot.attributes
    a.text[] = Agents.agent2string(model, p.pos[][idx]) # weird af special case
    a.visible[] = true

    return true
end

Agents.ids_to_inspect(model::ABM{Nothing}, pos) = []

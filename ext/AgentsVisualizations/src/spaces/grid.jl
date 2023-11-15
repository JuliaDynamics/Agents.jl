## Required

Agents.agents_space_dimensionality(::Agents.AbstractGridSpace{D}) where {D} = D

function Agents.get_axis_limits!(model::ABM{<:Agents.AbstractGridSpace})
    e = size(abmspace(model)) .+ 0.5
    o = zero.(e) .+ 0.5
    return o, e
end

## Optional

## Lifting

## Inspection

Agents.ids_to_inspect(model::ABM{<:Agents.AbstractGridSpace}, agent_pos) =
    ids_in_position(agent_pos, model)

function Agents.ids_to_inspect(model::ABM{<:GridSpaceSingle}, agent_pos)
    id = id_in_position(agent_pos, model)
    if id == 0
        return ()
    else
        return (id,)
    end
end

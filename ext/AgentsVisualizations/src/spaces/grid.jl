## Required

Agents.agents_space_dimensionality(::Agents.AbstractGridSpace{D}) where {D} = D

function Agents.get_axis_limits!(model::ABM{<:Agents.AbstractGridSpace})
    e = size(abmspace(model)) .+ 0.5
    o = zero.(e) .+ 0.5
    return o, e
end

## Preplots

## Lifting

function Agents.abmplot_heatobs(model::ABM{<:Agents.AbstractGridSpace}, heatarray)
    isnothing(heatarray) && return nothing
    # TODO: use surface!(heatobs) here?
    matrix = Agents.get_data(model, heatarray, identity)
    if !(matrix isa AbstractMatrix) || size(matrix) ≠ size(abmspace(model))
        error("The heat array property must yield a matrix of same size as the grid!")
    end
    return matrix
end

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

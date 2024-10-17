## Required

Agents.agents_space_dimensionality(::Agents.AbstractGridSpace{D}) where {D} = D

function Agents.get_axis_limits(model::ABM{<:Agents.AbstractGridSpace})
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

function Agents.convert_element_pos(s::S, pos) where {S<:Agents.AbstractGridSpace}
    gridpos = pos[1:length(spacesize(s))]
    Tuple(round.(Int, gridpos)) # using round to handle positions with offset
end
function Agents.ids_to_inspect(model::ABM{<:GridSpaceSingle}, pos)
    id = id_in_position(pos, model)
    return id == 0 ? () : (id,)
end

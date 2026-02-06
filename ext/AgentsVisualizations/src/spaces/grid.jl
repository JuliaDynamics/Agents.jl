## Required
function Agents.space_axis_limits(space::Agents.AbstractGridSpace)
    e = size(space) .+ 0.5
    o = zero.(e) .+ 0.5
    return Tuple(zip(o, e))
end

function abmheatmap!(ax, abmobs::ABMObservable, space::Agents.AbstractGridSpace, heatobs, heatkwargs)
    hmap = Makie.heatmap!(
        ax, heatobs;
        colormap=JULIADYNAMICS_CMAP, heatkwargs
    )
    return hmap
end

function abmplot_heatarray(model::ABM{<:Agents.AbstractGridSpace}, heatarray)
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

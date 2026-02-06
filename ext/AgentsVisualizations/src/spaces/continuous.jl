## Required
function Agents.space_axis_limits(space::ContinuousSpace)
    e = space.extent
    o = zero.(e)
    return Tuple(zip(o, e))
end

function Agents.abmheatmap!(ax, abmobs::ABMObservable, space::ContinuousSpace, heatobs, heatkwargs)
    nbinx, nbiny = size(heatobs[])
    extx, exty = space.extent
    coordx = range(0, extx; length=nbinx)
    coordy = range(0, exty; length=nbiny)
    hmap = Makie.heatmap!(ax, coordx, coordy, heatobs;
        colormap = JULIADYNAMICS_CMAP, heatkwargs...
    )
    return hmap
end


## Inspection

Agents.ids_to_inspect(model::ABM{<:ContinuousSpace}, pos) =
    nearby_ids_exact(pos, model, 0.00001)

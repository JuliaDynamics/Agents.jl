## Required

Agents.space_axis_dimensionality(::ContinuousSpace{D}) where {D} = D

function Agents.space_axis_limits(space::ContinuousSpace)
    e = space.extent
    o = zero.(e)
    return o, e
end

## Preplots

"""
Plot heatmap according to given `heatarray`.
Special method for models with `ContinuousSpace`.
"""
function abmheatmap!(ax, abmobs::ABMObservable, space::ContinuousSpace, heatarray, heatkwargs)
    heatobs = @lift(abmplot_heatarray($(abmobs.model), heatarray))
    nbinx, nbiny = size(heatobs[])
    extx, exty = space.extent
    coordx = range(0, extx; length=nbinx)
    coordy = range(0, exty; length=nbiny)
    hmap = Makie.heatmap!(ax, coordx, coordy, heatobs;
        colormap=JULIADYNAMICS_CMAP, heatkwargs...
    )

    # TODO: Set colorbar to be "glued" to axis
    # Problem with the following code, which comes from the tutorial
    # https://makie.juliaplots.org/stable/tutorials/aspect-tutorial/ ,
    # is that it only works for axis that have 1:1 aspect ratio...
    # rowsize!(fig[1, 1].layout, 1, ax.scene.px_area[].widths[2])
    # colsize!(fig[1, 1].layout, 1, Aspect(1, 1.0))
    return hmap
end

## Lifting

## Inspection

Agents.ids_to_inspect(model::ABM{<:ContinuousSpace}, pos) =
    nearby_ids_exact(pos, model, 0.00001)

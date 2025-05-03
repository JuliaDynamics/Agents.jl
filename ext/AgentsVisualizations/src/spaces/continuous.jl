## Required

Agents.agents_space_dimensionality(::ContinuousSpace{D}) where {D} = D

function Agents.get_axis_limits(model::ABM{<:ContinuousSpace})
    e = abmspace(model).extent
    o = zero.(e)
    return o, e
end

## Preplots

"""
Plot heatmap according to given `heatarray`.
Special method for models with `ContinuousSpace`.
"""
function heatmap!(ax, p::ABMP{S}) where {S<:ContinuousSpace}
    heatobs = @lift(abmplot_heatobs($(p.abmobs[].model), p.heatarray[]))
    isnothing(heatobs[]) && return nothing

    nbinx, nbiny = size(heatobs[])
    extx, exty = abmspace(p.abmobs[].model[]).extent
    coordx = range(0, extx; length=nbinx)
    coordy = range(0, exty; length=nbiny)
    hmap = Makie.heatmap!(p, coordx, coordy, heatobs;
        colormap=JULIADYNAMICS_CMAP, p.heatkwargs...
    )

    p.add_colorbar[] && Colorbar(ax.parent[1, 1][1, 2], hmap, width=20)
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

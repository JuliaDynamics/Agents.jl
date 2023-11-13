"Get correct axis limits for `ContinuousSpace` models."
function get_axis_limits!(model::ABM{<:ContinuousSpace})
    e = abmspace(model).extent
    o = zero.(e)
    return o, e
end

"""
Plot heatmap according to given `heatarray`.
Special method for models with `ContinuousSpace`.
"""
function heatmap!(ax,
    abmplot::_ABMPlot{<:Tuple{<:ABMObservable{<:Observable{<:ABM{<:S}}}}}) where 
        {S<:Agents.ContinuousSpace}
    heatobs = @lift(abmplot_heatobs($(abmplot.abmobs[].model), abmplot.heatarray))
    isnothing(heatobs[]) && return nothing
    
    nbinx, nbiny = size(heatobs[])
    extx, exty = abmspace(abmplot.abmobs[].model[]).extent
    coordx = range(0, extx; length=nbinx)
    coordy = range(0, exty; length=nbiny)
    hmap = Makie.heatmap!(abmplot, coordx, coordy, heatobs;
        colormap=JULIADYNAMICS_CMAP, abmplot.heatkwargs...
    )
    
    abmplot.add_colorbar[] && Colorbar(ax.parent[1, 1][1, 2], hmap, width=20)
    # TODO: Set colorbar to be "glued" to axis
    # Problem with the following code, which comes from the tutorial
    # https://makie.juliaplots.org/stable/tutorials/aspect-tutorial/ ,
    # is that it only works for axis that have 1:1 aspect ratio...
    # rowsize!(fig[1, 1].layout, 1, ax.scene.px_area[].widths[2])
    # colsize!(fig[1, 1].layout, 1, Aspect(1, 1.0))
    return hmap
end

## API functions for lifting

agents_space_dimensionality(::ContinuousSpace{D}) where {D} = D

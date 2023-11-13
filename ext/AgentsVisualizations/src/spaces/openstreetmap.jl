## Preplotting

"""
`OpenStreetMapSpace` preplot that takes `preplotkwargs` and creates an `OSMMakie.osmplot` 
with them in the given Makie axis.
"""
function preplot!(ax, model<:ABM{S::OpenStreetMapSpace}; preplotkwargs...)
    return Agents.osmplot!(ax, model; preplotkwargs...)
end

## API functions for lifting

function abmplot_pos(model::ABM{<:OpenStreetMapSpace}, offset, ids)
    if isnothing(offset)
        return [Point2f(OSM.lonlat(model[i].pos, model)) for i in ids]
    else
        return [Point2f(OSM.lonlat(model[i].pos, model) .+ offset(model[i])) for i in ids]
    end
end

agents_space_dimensionality(::OpenStreetMapSpace) = 2

"Get correct axis limits for `OpenStreetMapSpace` models."
function get_axis_limits!(model::ABM{<:Agents.OpenStreetMapSpace})
    o = [Inf, Inf]
    e = [-Inf, -Inf]
    for i ∈ Agents.positions(model)
        x, y = Agents.OSM.lonlat(i, model)
        o[1] = min(x, o[1])
        o[2] = min(y, o[2])
        e[1] = max(x, e[1])
        e[2] = max(y, e[2])
    end
    return o, e
end

## Preplotting

"""
`OpenStreetMapSpace` preplot that takes `preplotkwargs` and creates an `OSMMakie.osmplot` 
with them in the given Makie axis.
"""
function preplot!(ax, model::ABM{<:OpenStreetMapSpace}; preplotkwargs...)
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

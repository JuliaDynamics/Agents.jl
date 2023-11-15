## Required

Agents.agents_space_dimensionality(::OpenStreetMapSpace) = 2

"Get correct axis limits for `OpenStreetMapSpace` models."
function Agents.get_axis_limits!(model::ABM{<:OpenStreetMapSpace})
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

## Preplots

"""
`OpenStreetMapSpace` preplot that takes `preplotkwargs` and creates an `OSMMakie.osmplot` 
with them in the given Makie axis.
"""
function Agents.spaceplot!(ax::Axis, model::ABM{<:OpenStreetMapSpace}; preplotkwargs...)
    return Agents.osmplot!(ax, model; preplotkwargs...)
end

## Lifting

function Agents.abmplot_pos(model::ABM{<:OpenStreetMapSpace}, offset, ids)
    if isnothing(offset)
        return [Point2f(OSM.lonlat(model[i].pos, model)) for i in ids]
    else
        return [Point2f(OSM.lonlat(model[i].pos, model) .+ offset(model[i])) for i in ids]
    end
end

## Inspection

Agents.ids_to_inspect(model::ABM{<:OpenStreetMapSpace}, agent_pos) =
    nearby_ids(agent_pos, model, 0.0)

## Required

Agents.agents_space_dimensionality(::OSMSpace) = 2

function Agents.get_axis_limits(model::ABM{<:OSMSpace})
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
`OSMSpace` preplot that takes `spaceplotkwargs` and creates an `OSMMakie.osmplot` 
with them in the given Makie axis.
"""
function Agents.spaceplot!(ax::Axis, p::ABMP{<:OSMSpace}; spaceplotkwargs...)
    return Agents.osmplot!(ax, p; spaceplotkwargs...)
end

## Lifting

function Agents.abmplot_pos(model::ABM{<:OSMSpace}, offset)
    ids = allids(model)
    if isnothing(offset)
        return [Point2f(OSM.lonlat(model[i].pos, model)) for i in ids]
    else
        return [Point2f(OSM.lonlat(model[i].pos, model) .+ offset(model[i])) for i in ids]
    end
end

## Inspection

Agents.ids_to_inspect(model::ABM{<:OSMSpace}, pos) = nearby_ids(pos, model, 0.0)

module AgentsOSMVisualizations

using Agents, Makie, OSMMakie
using Agents.OSM

## Required
function Agents.space_axis_limits(model::ABM{<:OSMSpace})
    o = [Inf, Inf]
    e = [-Inf, -Inf]
    for i ∈ Agents.positions(model)
        x, y = Agents.OSM.lonlat(i, model)
        o[1] = min(x, o[1])
        o[2] = min(y, o[2])
        e[1] = max(x, e[1])
        e[2] = max(y, e[2])
    end
    return ((o[1], e[1]), (o[2], e[2]))
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

# Inspection, currently disabled
# Agents.ids_to_inspect(model::ABM{<:OSMSpace}, pos) = nearby_ids(pos, model, 0.0)

# Change defaults
default_colors = OSMMakie.WAYTYPECOLORS
default_colors["primary"] = colorant"#a1777f"
default_colors["secondary"] = colorant"#a18f78"
default_colors["tertiary"] = colorant"#b3b381"

function Agents.osmplot!(ax::Axis, p::_ABMPlot; kwargs...)
    osm_plot = OSMMakie.osmplot!(ax, abmspace(p.abmobs[].model[]).map;
        graphplotkwargs = (; arrow_show = false), kwargs...
    )
    osm_plot.plots[1].plots[1].plots[1].inspectable[] = false
    osm_plot.plots[1].plots[3].inspectable[] = false
    return
end

end

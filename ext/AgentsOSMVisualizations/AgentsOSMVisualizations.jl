module AgentsOSMVisualizations

using Agents, Makie, OSMMakie

# Required
function Agents.space_axis_limits(model::Agents.ABM{<:OpenStreetMapSpace})
    o = [Inf, Inf]
    e = [-Inf, -Inf]
    for i in Agents.positions(model)
        x, y = Agents.OSM.lonlat(i, model)
        o[1] = min(x, o[1])
        o[2] = min(y, o[2])
        e[1] = max(x, e[1])
        e[2] = max(y, e[2])
    end
    return ((o[1], e[1]), (o[2], e[2]))
end

# Optional, but must be extended for OSM

# space plotting
function Agents.spaceplot!(ax::Axis, space::Agents.OpenStreetMapSpace; kw...)
    osm_plot = OSMMakie.osmplot!(
        ax, space.map;
        graphplotkwargs = (; arrow_show = false), kw...
    )
    # osm_plot.plots[1].plots[1].plots[1].inspectable[] = false
    # osm_plot.plots[1].plots[3].inspectable[] = false
    return
end

# agent plotting; must be implemented as well, as the space needs to convert to lon-lat
# the source of this function is the same with the default `agentsplot!`, with the exception
# that `pos` is evaluated via a different function
function Agents.agentsplot!(ax, model::T, agent_color, agent_size, agent_marker, offset, agentsplotkwargs) where {T <: Observable{A} where {A <: ABM{<:OpenStreetMapSpace}}}
    pos = lift((x, y) -> osm_plot_pos(x, y), model, offset)
    AViz = Base.get_extension(Agents, :AgentsVisualizations)
    color = lift((x, y) -> AViz.abmplot_colors(x, y), model, agent_color)
    marker = lift((x, y, z) -> AViz.abmplot_markers(x, y, z), model, agent_marker, pos)
    markersize = lift((x, y) -> AViz.abmplot_markersizes(x, y), model, agent_size)
    if AViz.user_used_polygons(marker)
        poly!(ax, marker; color, agentsplotkwargs...)
    else
        scatter!(ax, pos; color, marker, markersize, agentsplotkwargs...)
    end
    return
end

function osm_plot_pos(model::ABM{<:OSMSpace}, offset)
    ids = allids(model)
    if isnothing(offset)
        return [Point2f(Agents.OSM.lonlat(model[i].pos, model)) for i in ids]
    else
        return [Point2f(Agents.OSM.lonlat(model[i].pos, model) .+ offset(model[i])) for i in ids]
    end
end

# Change defaults
default_colors = OSMMakie.WAYTYPECOLORS
default_colors["primary"] = colorant"#a1777f"
default_colors["secondary"] = colorant"#a18f78"
default_colors["tertiary"] = colorant"#b3b381"

# Inspection, currently disabled
# Agents.ids_to_inspect(model::ABM{<:OSMSpace}, pos) = nearby_ids(pos, model, 0.0)

end

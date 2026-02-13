space_axis_dimensionality(model::ABM) = space_axis_dimensionality(abmspace(model))
space_axis_dimensionality(space::Agents.AbstractSpace) = length(space_axis_limits(space))

Agents.spaceplot!(ax, model::ABM; kw...) = spaceplot!(ax, abmspace(model); kw...)
Agents.spaceplot!(ax, model::Agents.AbstractSpace; kw...) = nothing

function Agents.agentsplot!(ax, model::Observable{<:ABM}, agent_color, agent_size, agent_marker, offset, agentsplotkwargs)
    pos, color, marker, markersize = lift_attributes(
        model, agent_color, agent_size, agent_marker, offset
    )
    if user_used_polygons(marker) && ax <: Axis2
        poly!(ax, marker; color, agentsplotkwargs...)
    else
        scatter!(ax, pos; color, marker, markersize, agentsplotkwargs...)
    end
    return
end

## Default lifting
function lift_attributes(model, ac, as, am, offset)
    pos = lift((x, y) -> abmplot_pos(x, y), model, offset)
    color = lift((x, y) -> abmplot_colors(x, y), model, ac)
    marker = lift((x, y, z) -> abmplot_markers(x, y, z), model, am, pos)
    markersize = lift((x, y) -> abmplot_markersizes(x, y), model, as)
    return pos, color, marker, markersize
end

function abmplot_pos(model::ABM, offset)
    postype = space_axis_dimensionality(abmspace(model)) == 3 ? Point3f : Point2f
    if isnothing(offset)
        return postype[postype(model[i].pos) for i in allids(model)]
    else
        return postype[postype(model[i].pos .+ offset(model[i])) for i in allids(model)]
    end
end

abmplot_colors(model::ABM, ac) = to_color(ac)
abmplot_colors(model::ABM, ac::Function) = to_color.([ac(model[i]) for i in allids(model)])

function abmplot_markers(model::ABM, am, pos)
    if user_used_polygons(am)
        # for polygons we always need vector, even if all agents are same polygon
        return [translate_polygon(am, p) for p in pos]
    else
        return am
    end
end

function abmplot_markers(model::ABM, am::Function, pos)
    marker = [am(model[i]) for i in allids(model)]
    if user_used_polygons(marker)
        marker = [translate_polygon(m, p) for (m, p) in zip(marker, pos)]
    end
    return marker
end

abmplot_markersizes(model::ABM, as) = as
abmplot_markersizes(model::ABM, as::Function) = [as(model[i]) for i in allids(model)]


user_used_polygons(marker) = false
user_used_polygons(marker::Makie.Polygon) = true
user_used_polygons(marker::Observable{<:Makie.Polygon}) = true
user_used_polygons(marker::Vector{<:Makie.Polygon}) = true
user_used_polygons(marker::Observable{<:Vector{<:Makie.Polygon}}) = true

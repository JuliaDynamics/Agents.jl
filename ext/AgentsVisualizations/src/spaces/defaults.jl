space_axis_dimensionality(model::ABM) = space_axis_dimensionality(abmspace(model))
space_axis_dimensionality(space::Agents.AbstractSpace) = length(space_axis_limits(space))

Agents.spaceplot!(ax, model::ABM; kw...) = spaceplot!(ax, abmspace(model); kw...)
Agents.spaceplot!(ax, model::Agents.AbstractSpace; kw...) = nothing

function Agents.agentsplot!(ax::Axis, space, pos, color, marker, markersize, agentsplotkwargs)
    if user_used_polygons(marker)
        poly!(ax, marker; color, agentsplotkwargs...)
    else
        scatter!(ax, pos; color, marker, markersize, agentsplotkwargs...)
    end
    return
end

function Agents.agentsplot!(ax::Axis3, space, pos, color, marker, markersize, agentsplotkwargs)
    if marker === :circle
        marker = Sphere(Point3f(0), 1)
    end
    meshscatter!(ax, pos; color, marker, markersize, agentsplotkwargs...)
    return p
end

## Lifting

function abmplot_heatarray(model::ABM, heatarray)
    isnothing(heatarray) && return nothing
    # TODO: use surface!(heatobs) here?
    matrix = Agents.get_data(model, heatarray, identity)
    return matrix
end

function Agents.abmplot_pos(model::ABM, offset)
    postype = space_axis_dimensionality(abmspace(model)) == 3 ? Point3f : Point2f
    if isnothing(offset)
        return postype[postype(model[i].pos) for i in allids(model)]
    else
        return postype[postype(model[i].pos .+ offset(model[i])) for i in allids(model)]
    end
end

Agents.abmplot_colors(model::ABM, ac) = to_color(ac)
Agents.abmplot_colors(model::ABM, ac::Function) =
    to_color.([ac(model[i]) for i in allids(model)])

function Agents.abmplot_markers(model::ABM, am, pos)
    marker = am
    if user_used_polygons(am, marker)
        # for polygons we always need vector, even if all agents are same polygon
        marker = [translate(am, p) for p in pos]
    end
    return marker
end

function Agents.abmplot_markers(model::ABM, am::Function, pos)
    marker = [am(model[i]) for i in allids(model)]
    if user_used_polygons(marker)
        marker = [translate_polygon(m, p) for (m, p) in zip(marker, pos)]
    end
    return marker
end

user_used_polygons(marker) = false
user_used_polygons(marker::Makie.Polygon) = true
user_used_polygons(marker::Vector{<:Makie.Polygon}) = true

Agents.abmplot_markersizes(model::ABM, as) = as
Agents.abmplot_markersizes(model::ABM, as::Function) = [as(model[i]) for i in allids(model)]

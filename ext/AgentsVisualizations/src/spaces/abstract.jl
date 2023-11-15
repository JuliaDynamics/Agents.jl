Agents.agents_space_dimensionality(model::ABM{<:Agents.SpaceType}) = 
    Agents.agents_space_dimensionality(abmspace(model))

"Plot agents into a 2D space."
function Agents.agentsplot!(ax::Axis, model::ABM{<:Agents.SpaceType}, p::_ABMPlot)
    if p._used_poly[]
        poly_plot = poly!(p, p.marker; p.color, p.scatterkwargs...)
        poly_plot.inspectable[] = false # disable inspection for poly until fixed
    else
        scatter!(p, p.pos; p.color, p.marker, p.markersize, p.scatterkwargs...)
    end
    return p
end

"Plot agents into a 3D space."
function Agents.agentsplot!(ax::Axis3, model::ABM{<:Agents.SpaceType}, p::_ABMPlot)
    p.marker[] == :circle && (p.marker[] = Sphere(Point3f(0), 1))
    meshscatter!(p, p.pos; p.color, p.marker, p.markersize, p.scatterkwargs...)
    return p
end

## Preplots

Agents.spaceplot!(ax::Axis, model::ABM{<:Agents.SpaceType}; preplotkwargs...) = nothing
Agents.spaceplot!(ax::Axis3, model::ABM{<:Agents.SpaceType}; preplotkwargs...) = nothing

function Agents.static_preplot!(ax::Axis, model::ABM{<:Agents.SpaceType}, p::_ABMPlot)
    hasproperty(p, :static_preplot!) && return old_static_preplot!(ax, model, p)
    return nothing
end

function Agents.static_preplot!(ax::Axis3, model::ABM{<:Agents.SpaceType}, p::_ABMPlot)
    hasproperty(p, :static_preplot!) && return old_static_preplot!(ax, model, p)
    return nothing
end

function old_static_preplot!(ax, model, p)
    @warn """Usage of the static_preplot! kwarg is deprecated.
        Please remove it from the call to abmplot and define a custom method for 
        Agents.static_preplot!(ax, model, p) instead."""
    return p.static_preplot![](ax, model)
end

## Lifting

function Agents.abmplot_heatobs(model::ABM{<:Agents.SpaceType}, heatarray)
    isnothing(heatarray) && return nothing
    # TODO: use surface!(heatobs) here?
    matrix = Agents.get_data(model, heatarray, identity)
    return matrix
end

Agents.abmplot_ids(model::ABM{<:Agents.SpaceType}) = allids(model)

function Agents.abmplot_pos(model::ABM{<:Agents.SpaceType}, offset, ids)
    postype = agents_space_dimensionality(abmspace(model)) == 3 ? Point3f : Point2f
    if isnothing(offset)
        return [postype(model[i].pos) for i in ids]
    else
        return [postype(model[i].pos .+ offset(model[i])) for i in ids]
    end
end

Agents.abmplot_colors(model::ABM{<:Agents.SpaceType}, ac, ids) = to_color(ac)
Agents.abmplot_colors(model::ABM{<:Agents.SpaceType}, ac::Function, ids) =
    to_color.([ac(model[i]) for i in ids])

function Agents.abmplot_marker(model::ABM{<:Agents.SpaceType}, used_poly, am, pos, ids)
    marker = am
    # need to update used_poly Observable here for inspection
    used_poly[] = user_used_polygons(am, marker)
    if used_poly[] # for polygons we always need vector, even if all agents are same polygon
        marker = [translate(am, p) for p in pos]
    end
    return marker
end

function Agents.abmplot_marker(model::ABM{<:Agents.SpaceType}, used_poly, am::Function, pos, ids)
    marker = [am(model[i]) for i in ids]
    # need to update used_poly Observable here for use with inspection
    used_poly[] = user_used_polygons(am, marker)
    if used_poly[]
        marker = [translate_polygon(m, p) for (m, p) in zip(marker, pos)]
    end
    return marker
end

user_used_polygons(am, marker) = false
user_used_polygons(am::Makie.Polygon, marker) = true
user_used_polygons(am::Function, marker::Vector{<:Makie.Polygon}) = true

Agents.abmplot_markersizes(model::ABM{<:Agents.SpaceType}, as, ids) = as
Agents.abmplot_markersizes(model::ABM{<:Agents.SpaceType}, as::Function, ids) =
    [as(model[i]) for i in ids]

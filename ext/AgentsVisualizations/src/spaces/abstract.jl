"Plot space and/or set axis limits."
function set_axis_limits!(ax::Axis, model::ABM{<:Agents.AbstractSpace})
    o, e = get_axis_limits!(model)
    any(isnothing, (o, e)) && return nothing
    xlims!(ax, o[1], e[1])
    ylims!(ax, o[2], e[2])
    length(o) == 3 && zlims!(ax, o[3], e[3])
    return o, e
end

function set_axis_limits!(ax::Axis3, model::ABM{<:Agents.AbstractSpace})
    o, e = get_axis_limits!(model)
    any(isnothing, (o, e)) && return nothing
    xlims!(ax, o[1], e[1])
    ylims!(ax, o[2], e[2])
    zlims!(ax, o[3], e[3])
    return o, e
end

Agents.agents_space_dimensionality(model::ABM{<:Agents.AbstractSpace}) = 
    Agents.agents_space_dimensionality(abmspace(model))

"Plot agents into a 2D space."
function Agents.plot_agents!(ax::Axis, model::ABM{<:Agents.AbstractSpace}, p::_ABMPlot)
    if p._used_poly[]
        poly_plot = poly!(p, p.marker; p.color, p.scatterkwargs...)
        poly_plot.inspectable[] = false # disable inspection for poly until fixed
    else
        scatter!(p, p.pos; p.color, p.marker, p.markersize, p.scatterkwargs...)
    end
    return p
end

"Plot agents into a 3D space."
function Agents.plot_agents!(ax::Axis3, model::ABM{<:Agents.AbstractSpace}, p::_ABMPlot)
    p.marker[] == :circle && (p.marker[] = Sphere(Point3f(0), 1))
    meshscatter!(p, p.pos; p.color, p.marker, p.markersize, p.scatterkwargs...)
    return p
end

## Optional

"Plot heatmap according to given `heatarray`."
function heatmap!(ax, p::_ABMPlot)
    heatobs = @lift(abmplot_heatobs($(p.abmobs[].model), p.heatarray[]))
    isnothing(heatobs[]) && return nothing
    hmap = Makie.heatmap!(p, heatobs; 
        colormap=JULIADYNAMICS_CMAP, p.heatkwargs...)
    p.add_colorbar[] && Colorbar(ax.parent[1, 1][1, 2], hmap, width=20)
    # TODO: Set colorbar to be "glued" to axis
    # Problem with the following code, which comes from the tutorial
    # https://makie.juliaplots.org/stable/tutorials/aspect-tutorial/ ,
    # is that it only works for axis that have 1:1 aspect ratio...
    # rowsize!(fig[1, 1].layout, 1, ax.scene.px_area[].widths[2])
    # colsize!(fig[1, 1].layout, 1, Aspect(1, 1.0))
    return hmap
end

function Agents.static_preplot!(ax::Axis, model::ABM{<:Agents.AbstractSpace}, p::_ABMPlot)
    if hasproperty(p, :static_preplot!)
        @warn """Usage of the static_preplot! kwarg is deprecated.
        Please remove it from the call to abmplot and define a custom method for 
        static_preplot!(ax, model, p) instead."""
        return p.static_preplot![](ax, model)
    end
    return nothing
end

function Agents.static_preplot!(ax::Axis3, model::ABM{<:Agents.AbstractSpace}, p::_ABMPlot)
    if hasproperty(p, :static_preplot!)
        @warn """Usage of the static_preplot! kwarg is deprecated.
        Please remove it from the call to abmplot and define a custom method for 
        static_preplot!(ax, model, p) instead."""
        return p.static_preplot![](ax, model)
    end
    return nothing
end

Agents.preplot!(ax::Axis, model::ABM{<:Agents.AbstractSpace}; preplotkwargs...) = nothing
Agents.preplot!(ax::Axis3, model::ABM{<:Agents.AbstractSpace}; preplotkwargs...) = nothing

## Lifting

function abmplot_heatobs(model::ABM{<:Agents.AbstractSpace}, heatarray)
    isnothing(heatarray) && return nothing
    # TODO: use surface!(heatobs) here?
    matrix = Agents.get_data(model, heatarray, identity)
    # Check for correct size for discrete space
    if abmspace(model) isa Agents.AbstractGridSpace
        if !(matrix isa AbstractMatrix) || size(matrix) ≠ size(abmspace(model))
            error("The heat array property must yield a matrix of same size as the grid!")
        end
    end
    return matrix
end

Agents.abmplot_ids(model::ABM{<:Agents.AbstractSpace}) = allids(model)

function Agents.abmplot_pos(model::ABM{<:Agents.AbstractSpace}, offset, ids)
    postype = agents_space_dimensionality(abmspace(model)) == 3 ? Point3f : Point2f
    if isnothing(offset)
        return [postype(model[i].pos) for i in ids]
    else
        return [postype(model[i].pos .+ offset(model[i])) for i in ids]
    end
end

Agents.abmplot_colors(model::ABM{<:Agents.AbstractSpace}, ac, ids) = to_color(ac)
Agents.abmplot_colors(model::ABM{<:Agents.AbstractSpace}, ac::Function, ids) =
    to_color.([ac(model[i]) for i in ids])

function Agents.abmplot_marker(model::ABM{<:Agents.AbstractSpace}, used_poly, am, pos, ids)
    marker = am
    # need to update used_poly Observable here for inspection
    used_poly[] = user_used_polygons(am, marker)
    if used_poly[] # for polygons we always need vector, even if all agents are same polygon
        marker = [translate(am, p) for p in pos]
    end
    return marker
end

function Agents.abmplot_marker(model::ABM{<:Agents.AbstractSpace}, used_poly, am::Function, pos, ids)
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

Agents.abmplot_markersizes(model::ABM{<:Agents.AbstractSpace}, as, ids) = as
Agents.abmplot_markersizes(model::ABM{<:Agents.AbstractSpace}, as::Function, ids) =
    [as(model[i]) for i in ids]

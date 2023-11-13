"Plot space and/or set axis limits."
function set_axis_limits!(ax::Axis, model<:ABM{S<:DEFAULT_SPACES})
    o, e = get_axis_limits!(model)
    any(isnothing, (o, e)) && return nothing
    xlims!(ax, o[1], e[1])
    ylims!(ax, o[2], e[2])
    length(o) == 3 && zlims!(ax, o[3], e[3])
    return o, e
end

function set_axis_limits!(ax::Axis3, model<:ABM{S<:DEFAULT_SPACES})
    o, e = get_axis_limits!(model)
    any(isnothing, (o, e)) && return nothing
    xlims!(ax, o[1], e[1])
    ylims!(ax, o[2], e[2])
    zlims!(ax, o[3], e[3])
    return o, e
end

"Plot heatmap according to given `heatarray`."
function heatmap!(ax, abmplot::_ABMPlot)
    heatobs = @lift(abmplot_heatobs($(abmplot.abmobs[].model), abmplot.heatarray))
    isnothing(heatobs[]) && return nothing
    hmap = Makie.heatmap!(abmplot, heatobs; 
        colormap=JULIADYNAMICS_CMAP, abmplot.heatkwargs...)
    abmplot.add_colorbar[] && Colorbar(ax.parent[1, 1][1, 2], hmap, width=20)
    # TODO: Set colorbar to be "glued" to axis
    # Problem with the following code, which comes from the tutorial
    # https://makie.juliaplots.org/stable/tutorials/aspect-tutorial/ ,
    # is that it only works for axis that have 1:1 aspect ratio...
    # rowsize!(fig[1, 1].layout, 1, ax.scene.px_area[].widths[2])
    # colsize!(fig[1, 1].layout, 1, Aspect(1, 1.0))
    return hmap
end

function abmplot_heatobs(model, heatarray)
    heatobs = begin
        if !isnothing(heatarray)
            # TODO: use surface!(heatobs) here?
            matrix = Agents.get_data(model, heatarray, identity)
            # Check for correct size for discrete space
            if abmspace(model) isa AbstractGridSpace
                if !(matrix isa AbstractMatrix) || size(matrix) ≠ size(abmspace(model))
                    error("The heat array property must yield a matrix of same size as the grid!")
                end
            end
            matrix
        else
            nothing
        end
    end
    return heatobs
end


## API functions for lifting

abmplot_ids(model::ABM{<:DEFAULT_SPACES}) = allids(model)

function abmplot_pos(model::ABM{<:DEFAULT_SPACES}, offset, ids)
    postype = agents_space_dimensionality(abmspace(model)) == 3 ? Point3f : Point2f
    if isnothing(offset)
        return [postype(model[i].pos) for i in ids]
    else
        return [postype(model[i].pos .+ offset(model[i])) for i in ids]
    end
end

agents_space_dimensionality(abm::ABM) = agents_space_dimensionality(abmspace(abm))

abmplot_colors(model::ABM{<:DEFAULT_SPACES}, ac, ids) = to_color(ac)
abmplot_colors(model::ABM{<:DEFAULT_SPACES}, ac::Function, ids) =
    to_color.([ac(model[i]) for i in ids])

function abmplot_marker(model::ABM{<:DEFAULT_SPACES}, used_poly, am, pos, ids)
    marker = am
    # need to update used_poly Observable here for inspection
    used_poly[] = user_used_polygons(am, marker)
    if used_poly[] # for polygons we always need vector, even if all agents are same polygon
        marker = [translate(am, p) for p in pos]
    end
    return marker
end

function abmplot_marker(model::ABM{<:DEFAULT_SPACES}, used_poly, am::Function, pos, ids)
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

abmplot_markersizes(model::ABM{<:DEFAULT_SPACES}, as, ids) = as
abmplot_markersizes(model::ABM{<:DEFAULT_SPACES}, as::Function, ids) =
    [as(model[i]) for i in ids]

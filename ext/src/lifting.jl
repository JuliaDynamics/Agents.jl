#=
In this file we define how agents are plotted and how the plots are updated while stepping.
=#

function lift_attributes(model, ac, as, am, offset, heatarray, used_poly)
    ids = @lift(abmplot_ids($model))
    pos = @lift(abmplot_pos($model, $offset, $ids))
    color = @lift(abmplot_colors($model, $ac, $ids))
    marker = @lift(abmplot_marker($model, used_poly, $am, $pos, $ids))
    markersize = @lift(abmplot_markersizes($model, $as, $ids))
    heatobs = @lift(abmplot_heatobs($model, $heatarray))

    return pos, color, marker, markersize, heatobs
end


#####
## ids
#####

abmplot_ids(model::ABM{<:SUPPORTED_SPACES}) = allids(model)
# for GraphSpace the collected ids are the indices of the graph nodes (= agent positions)
abmplot_ids(model::ABM{<:GraphSpace}) = eachindex(model.space.stored_ids)


#####
## positions
#####

function abmplot_pos(model::ABM{<:SUPPORTED_SPACES}, offset, ids)
    postype = agents_space_dimensionality(model.space) == 3 ? Point3f : Point2f
    if isnothing(offset)
        return [postype(model[i].pos) for i in ids]
    else
        return [postype(model[i].pos .+ offset(model[i])) for i in ids]
    end
end

function abmplot_pos(model::ABM{<:OpenStreetMapSpace}, offset, ids)
    if isnothing(offset)
        return [Point2f(OSM.lonlat(model[i].pos, model)) for i in ids]
    else
        return [Point2f(OSM.lonlat(model[i].pos, model) .+ offset(model[i])) for i in ids]
    end
end

abmplot_pos(model::ABM{<:GraphSpace}, offset, ids) = nothing

agents_space_dimensionality(abm::ABM) = agents_space_dimensionality(abm.space)
agents_space_dimensionality(::AbstractGridSpace{D}) where {D} = D
agents_space_dimensionality(::ContinuousSpace{D}) where {D} = D
agents_space_dimensionality(::OpenStreetMapSpace) = 2
agents_space_dimensionality(::GraphSpace) = 2


#####
## colors
#####

abmplot_colors(model::ABM{<:SUPPORTED_SPACES}, ac, ids) = to_color(ac)
abmplot_colors(model::ABM{<:SUPPORTED_SPACES}, ac::Function, ids) =
    to_color.([ac(model[i]) for i in ids])
# in GraphSpace we iterate over a list of agents (not agent ids) at a graph node position
abmplot_colors(model::ABM{<:GraphSpace}, ac::Function, ids) =
    to_color.(ac(model[id] for id in model.space.stored_ids[idx]) for idx in ids)

#####
## markers
#####

function abmplot_marker(model::ABM{<:SUPPORTED_SPACES}, used_poly, am, pos, ids)
    marker = am
    # need to update used_poly Observable here for inspection
    used_poly[] = user_used_polygons(am, marker)
    if used_poly[] # for polygons we always need vector, even if all agents are same polygon
        marker = [translate(am, p) for p in pos]
    end
    return marker
end

function abmplot_marker(model::ABM{<:SUPPORTED_SPACES}, used_poly, am::Function, pos, ids)
    marker = [am(model[i]) for i in ids]
    # need to update used_poly Observable here for use with inspection
    used_poly[] = user_used_polygons(am, marker)
    if used_poly[]
        marker = [translate(m, p) for (m, p) in zip(marker, pos)]
    end
    return marker
end

# TODO: Add support for polygon markers for GraphSpace if possible with GraphMakie
abmplot_marker(model::ABM{<:GraphSpace}, used_poly, am, pos, ids) = am
abmplot_marker(model::ABM{<:GraphSpace}, used_poly, am::Function, pos, ids) =
    [am(model[id] for id in model.space.stored_ids[idx]) for idx in ids]

user_used_polygons(am, marker) = false
user_used_polygons(am::Polygon, marker) = true
user_used_polygons(am::Function, marker::Vector{<:Polygon}) = true


#####
## markersizes
#####

abmplot_markersizes(model::ABM{<:SUPPORTED_SPACES}, as, ids) = as
abmplot_markersizes(model::ABM{<:SUPPORTED_SPACES}, as::Function, ids) =
    [as(model[i]) for i in ids]

abmplot_markersizes(model::ABM{<:GraphSpace}, as, ids) = as
abmplot_markersizes(model::ABM{<:GraphSpace}, as::Function, ids) =
    [as(model[id] for id in model.space.stored_ids[idx]) for idx in ids]


#####
## heatmap specific
#####

function abmplot_heatobs(model, heatarray)
    heatobs = begin
        if !isnothing(heatarray)
            # TODO: This is also possible for continuous spaces, we have to
            # get the matrix size, and then make a range for each dimension
            # and do heatmap!(ax, x, y, heatobs)
            #
            # TODO: use surface!(heatobs) here?
            matrix = get_data(model, heatarray, identity)
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


#####
##  GraphSpace specific functions for the edges
#####
abmplot_edge_color(model, ec) = to_color(ec)
abmplot_edge_color(model, ec::Function) = to_color.(ec(model))

abmplot_edge_width(model, ew) = ew
abmplot_edge_width(model, ew::Function) = ew(model)

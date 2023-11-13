"Get correct axis limits for `GraphSpace` models."
get_axis_limits!(model::ABM{<:GraphSpace}) = nothing, nothing

"Plot agents' positions."
function plot_agents!(ax, model::ABM{<:GraphSpace}; abmplot = first_abmplot_in(ax))
    hidedecorations!(ax)
    ec = get(abmplot.graphplotkwargs, :edge_color, Observable(:black))
    edge_color = @lift(abmplot_edge_color($(abmplot.abmobs[].model), $ec))
    ew = get(abmplot.graphplotkwargs, :edge_width, Observable(1))
    edge_width = @lift(abmplot_edge_width($(abmplot.abmobs[].model), $ew))
    Agents.graphplot!(abmplot, abmspace(model).graph;
        node_color=color, node_marker=marker, node_size=markersize,
        abmplot.graphplotkwargs, # must come first to not overwrite lifted kwargs
        edge_color, edge_width)
    return abmplot
end

## API functions for lifting

# for GraphSpace the collected ids are the indices of the graph nodes (= agent positions)
abmplot_ids(model::ABM{<:GraphSpace}) = eachindex(abmspace(model).stored_ids)

abmplot_pos(model::ABM{<:GraphSpace}, offset, ids) = nothing

agents_space_dimensionality(::GraphSpace) = 2

# in GraphSpace we iterate over a list of agents (not agent ids) at a graph node position
abmplot_colors(model::ABM{<:GraphSpace}, ac::Function, ids) =
    to_color.(ac(model[id] for id in abmspace(model).stored_ids[idx]) for idx in ids)

# TODO: Add support for polygon markers for GraphSpace if possible with GraphMakie
abmplot_marker(model::ABM{<:GraphSpace}, used_poly, am, pos, ids) = am
abmplot_marker(model::ABM{<:GraphSpace}, used_poly, am::Function, pos, ids) =
    [am(model[id] for id in abmspace(model).stored_ids[idx]) for idx in ids]

abmplot_markersizes(model::ABM{<:GraphSpace}, as, ids) = as
abmplot_markersizes(model::ABM{<:GraphSpace}, as::Function, ids) =
    [as(model[id] for id in abmspace(model).stored_ids[idx]) for idx in ids]

## GraphSpace functions for edge properties

abmplot_edge_color(model, ec) = to_color(ec)
abmplot_edge_color(model, ec::Function) = to_color.(ec(model))

abmplot_edge_width(model, ew) = ew
abmplot_edge_width(model, ew::Function) = ew(model)

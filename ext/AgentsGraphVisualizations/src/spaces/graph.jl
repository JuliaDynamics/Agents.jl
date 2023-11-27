## Required

Agents.agents_space_dimensionality(::GraphSpace) = 2

Agents.get_axis_limits(model::ABM{<:GraphSpace}) = nothing, nothing

function Agents.agentsplot!(ax::Axis, model::ABM{<:GraphSpace}, p::_ABMPlot)
    hidedecorations!(ax)
    ec = get(p.agentsplotkwargs, :edge_color, Observable(:black))
    edge_color = @lift(abmplot_edge_color($(p.abmobs[].model), $ec))
    ew = get(p.agentsplotkwargs, :edge_width, Observable(1))
    edge_width = @lift(abmplot_edge_width($(p.abmobs[].model), $ew))
    Agents.graphplot!(p, abmspace(model).graph;
        node_color=p.color, node_marker=p.marker, node_size=p.markersize,
        p.agentsplotkwargs, # must come first to not overwrite lifted kwargs
        edge_color, edge_width)
    return p
end

function Agents.agentsplot!(ax::Axis3, model::ABM{<:GraphSpace}, p::_ABMPlot)
    hidedecorations!(ax)
    ec = get(p.agentsplotkwargs, :edge_color, Observable(:black))
    edge_color = @lift(abmplot_edge_color($(p.abmobs[].model), $ec))
    ew = get(p.agentsplotkwargs, :edge_width, Observable(1))
    edge_width = @lift(abmplot_edge_width($(p.abmobs[].model), $ew))
    Agents.graphplot!(p, abmspace(model).graph;
        node_color=p.color, node_marker=p.marker, node_size=p.markersize,
        p.agentsplotkwargs, # must come first to not overwrite lifted kwargs
        edge_color, edge_width)
    return p
end

# Special GraphSpace functions for edge properties

abmplot_edge_color(model, ec) = to_color(ec)
abmplot_edge_color(model, ec::Function) = to_color.(ec(model))

abmplot_edge_width(model, ew) = ew
abmplot_edge_width(model, ew::Function) = ew(model)

## Lifting

# for GraphSpace the collected ids are the indices of the graph nodes (= agent positions)
Agents.abmplot_ids(model::ABM{<:GraphSpace}) = eachindex(abmspace(model).stored_ids)

Agents.abmplot_pos(model::ABM{<:GraphSpace}, offset, ids) = nothing

# in GraphSpace we iterate over a list of agents (not agent ids) at a graph node position
Agents.abmplot_colors(model::ABM{<:GraphSpace}, ac::Function, ids) =
    to_color.(ac(model[id] for id in abmspace(model).stored_ids[idx]) for idx in ids)

# TODO: Add support for polygon markers for GraphSpace if possible with GraphMakie
Agents.abmplot_marker(model::ABM{<:GraphSpace}, used_poly, am, pos, ids) = am
Agents.abmplot_marker(model::ABM{<:GraphSpace}, used_poly, am::Function, pos, ids) =
    [am(model[id] for id in abmspace(model).stored_ids[idx]) for idx in ids]

Agents.abmplot_markersizes(model::ABM{<:GraphSpace}, as, ids) = as
Agents.abmplot_markersizes(model::ABM{<:GraphSpace}, as::Function, ids) =
    [as(model[id] for id in abmspace(model).stored_ids[idx]) for idx in ids]

## Inspection

function Makie.show_data(inspector::DataInspector, 
        p::ABMP{<:GraphSpace}, idx, source::Scatter)
    pos = source.converted[1][][idx]
    proj_pos = Makie.shift_project(Makie.parent_scene(p), p, to_ndim(Point3f, pos, 0))
    Makie.update_tooltip_alignment!(inspector, proj_pos)

    # get GraphPlot
    gp = p.plots[findfirst(x -> isa(x, GraphMakie.GraphPlot), p.plots)]
    # get position (Int) matching currently hovered node position (Point2f/Point3f)
    node_pos = findfirst(==(pos), gp.node_pos[])

    model = p.abmobs[].model[]
    a = inspector.plot.attributes
    a.text[] = Agents.agent2string(model, node_pos)
    a.visible[] = true

    return true
end

Agents.ids_to_inspect(model::ABM{<:GraphSpace}, pos) =
    abmspace(model).stored_ids[pos]

function Agents.agent2string(model::ABM{<:GraphSpace}, pos)
    ids = Agents.ids_to_inspect(model, pos)

    return """▶ Node $pos
    # of agents: $(length(ids))
    """
end
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

# GraphSpace positions are automatically assigned by GraphMakie.graphplot and chosen layout
Agents.abmplot_pos(model::ABM{<:GraphSpace}, offset) = nothing

# in GraphSpace we iterate over a list of agents (not agent ids) at a graph node position
function Agents.abmplot_colors(model::ABM{<:GraphSpace}, ac::Function)
    nodes = eachindex(abmspace(model).stored_ids)
    return to_color.(ac(model[id] for id in abmspace(model).stored_ids[n]) for n in nodes)
end

# TODO: Add support for polygon markers for GraphSpace if possible with GraphMakie
Agents.abmplot_markers(model::ABM{<:GraphSpace}, am, pos) = am
function Agents.abmplot_markers(model::ABM{<:GraphSpace}, am::Function, pos)
    nodes = eachindex(abmspace(model).stored_ids)
    return [am(model[id] for id in abmspace(model).stored_ids[n]) for n in nodes]
end

Agents.abmplot_markersizes(model::ABM{<:GraphSpace}, as) = as
function Agents.abmplot_markersizes(model::ABM{<:GraphSpace}, as::Function)
    nodes = eachindex(abmspace(model).stored_ids)
    return [as(model[id] for id in abmspace(model).stored_ids[n]) for n in nodes]
end

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

function Agents.agent2string(model::ABM{<:GraphSpace}, pos)
    ids = Agents.ids_in_position(pos, model)

    return """▶ Node $pos
    # of agents: $(length(ids))
    """
end

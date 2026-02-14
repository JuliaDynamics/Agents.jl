module AgentsGraphVisualizations

using Agents, Makie, GraphMakie

# Required
Agents.space_axis_limits(::GraphSpace) = ((nothing, nothing),(nothing, nothing))

function Agents.agentsplot!(ax, model::T, agent_color, agent_size, agent_marker, offset, agentsplotkwargs) where {T <: Observable{A} where {A <: ABM{<:GraphSpace}}}
    hidedecorations!(ax)
    # lift basics from model
    color = @lift(graph_color($model, agent_color))
    marker = @lift(graph_marker($model, agent_marker))
    size = @lift(graph_size($model, agent_size))
    # Also lift properties of edges, if any
    ec = get(agentsplotkwargs, :edge_color, Observable(:black))
    edge_color = @lift(abmplot_edge_color($(model), ec))
    ew = get(agentsplotkwargs, :edge_width, Observable(1))
    edge_width = @lift(abmplot_edge_width($(model), ew))

    GraphMakie.graphplot!(ax, abmspace(model[]).graph;
        node_color = color, node_marker=marker, node_size=size,
        agentsplotkwargs..., # must come first to not overwrite lifted kwargs
        edge_color, edge_width
    )
    return
end

# Lifting (helper functions)
graph_color(model, ac) = ac
function graph_color(model, ac::Function)
    nodes = eachindex(abmspace(model).stored_ids)
    to_color.(ac(model[id] for id in abmspace(model).stored_ids[n]) for n in nodes)
end
graph_marker(model, am) = am
function graph_marker(model, am::Function)
    nodes = eachindex(abmspace(model).stored_ids)
    return [am(model[id] for id in abmspace(model).stored_ids[n]) for n in nodes]
end
graph_size(model, as) = as
function graph_size(model, as::Function)
    nodes = eachindex(abmspace(model).stored_ids)
    return [as(model[id] for id in abmspace(model).stored_ids[n]) for n in nodes]
end

abmplot_edge_color(model, ec) = to_color(ec)
abmplot_edge_color(model, ec::Function) = to_color.(ec(model))

abmplot_edge_width(model, ew) = ew
abmplot_edge_width(model, ew::Function) = ew(model)

# Inspection
# TODO: Update this after v7
# function Makie.show_data(inspector::DataInspector, p, # ::ABMP{<:GraphSpace},
#     idx, source::Scatter)
#     pos = Makie.position_on_plot(source, idx)
#     proj_pos = Makie.shift_project(Makie.parent_scene(p), pos)
#     Makie.update_tooltip_alignment!(inspector, proj_pos)

#     # get GraphPlot
#     gp = p.plots[findfirst(x -> isa(x, GraphMakie.GraphPlot), p.plots)]
#     # get position (Int) matching currently hovered node position (Point2f/Point3f)
#     node_pos = findfirst(==(pos), gp.node_pos[])
#     if isnothing(node_pos)
#         return false
#     end

#     model = p.abmobs[].model[]
#     a = inspector.plot.attributes
#     a.text[] = Agents.agent2string(model, node_pos)
#     a.visible[] = true

#     return true
# end

# function Agents.agent2string(model::ABM{<:GraphSpace}, pos)
#     ids = Agents.ids_in_position(pos, model)

#     return """▶ Node $pos
#     # of agents: $(length(ids))
#     """
# end


end
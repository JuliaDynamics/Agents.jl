
module AgentsGraphVisualizations

using Agents, GraphMakie

function Agents.agents_graphplot!(
    abmplot, 
    graph;
    node_color, 
    node_marker, 
    node_size,
    graphplotkwargs,
    edge_color, 
    edge_width)
    graphplot!(abmplot, graph; node_color=node_color, node_marker=node_marker, 
               node_size=node_size, graphplotkwargs..., # must come first to not overwrite lifted kwargs
               edge_color, edge_width)
end

end
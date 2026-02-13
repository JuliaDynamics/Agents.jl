module AgentsGraphVisualizations

using Agents, Makie, GraphMakie

include("src/spaces/graph.jl")

function Agents.graphplot!(ax, abmobs::ABMObservable;
        node_color, node_marker, node_size,
        agentsplotkwargs,
        edge_color, edge_width
    )
    graph = abmspace(abmobs.model[]).graph
    GraphMakie.graphplot!(ax, graph;
        node_color=node_color, node_marker=node_marker, node_size=node_size,
        agentsplotkwargs..., # must come first to not overwrite lifted kwargs
        edge_color, edge_width
    )
end

end
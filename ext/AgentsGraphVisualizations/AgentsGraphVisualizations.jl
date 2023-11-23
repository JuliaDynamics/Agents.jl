
module AgentsGraphVisualizations

using Agents, Makie, GraphMakie
const _ABMPlot = Agents.get_ABMPlot_type()
const ABMP{S} = _ABMPlot{<:Tuple{<:ABMObservable{<:Observable{<:ABM{<:S}}}}}

include("src/spaces/graph.jl")

function Agents.graphplot!(abmplot, graph;
        node_color, node_marker, node_size,
        agentsplotkwargs,
        edge_color, edge_width
    )
    GraphMakie.graphplot!(abmplot, graph;
        node_color=node_color, node_marker=node_marker, node_size=node_size,
        agentsplotkwargs..., # must come first to not overwrite lifted kwargs
        edge_color, edge_width
    )
end

end
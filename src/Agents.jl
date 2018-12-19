module Agents

export step!, AbstractModel, AbstractAgent, AbstractSpace, batchrunner, data_collector, grid, gridsize, move_agent!, add_agent!, coord_to_vertex, vertex_to_coord, get_node_contents, node_neighbors, nagents, return_activation_order, random_activation, as_added, visualize_data, add_agent_single!, move_agent_single!, kill_agent!, find_empty_nodes, find_empty_nodes_coords, id_to_agent, write_to_file, visualize_2D_agent_distribution, Random, combine_columns!, Node_iter, empty_cells, is_empty, pick_empty

using LightGraphs
using DataFrames
using VegaLite
using Random
import Base.Iterators: product
import StatsBase
using DataVoyager
using CSV
using ColorTypes
using Compose
using GraphPlot
import Base.iterate
import Base.length
# using PerceptualColourMaps

include("agents_component.jl")
include("model_component.jl")
include("space.jl")
include("scheduler.jl")
include("data_collector.jl")
include("batch_runner.jl")
include("visualization.jl")

end # module

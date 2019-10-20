module Agents

export step!, AbstractModel, AbstractAgent, AbstractSpace, batchrunner, data_collector, grid, gridsize, move_agent!, add_agent!, coord2vertex, vertex2coord, get_node_contents, node_neighbors, nagents, return_activation_order, random_activation, as_added, visualize_data, add_agent_single!, move_agent_single!, kill_agent!, find_empty_nodes, find_empty_nodes_coords, id_to_agent, write_to_file, visualize_2D_agent_distribution, Random, combine_columns!, Node_iter, empty_nodes, is_empty, pick_empty, partial_activation, dummystep, visualize_1DCA, visualize_2DCA, SimpleGraph, batchrunner_parallel

using Distributed
using LightGraphs
using DataFrames
using VegaLite
using Random
import Base.Iterators.product
import StatsBase
using DataVoyager
using CSV
using ColorTypes
using GraphPlot
using Compose
using Cairo, Fontconfig
import Base.iterate
import Base.length
include("agents_component.jl")
include("model_component.jl")
include("space.jl")
include("scheduler.jl")
include("data_collector.jl")
include("batch_runner.jl")
include("visualization.jl")
include("CA1D.jl")
include("CA2D.jl")

end # module

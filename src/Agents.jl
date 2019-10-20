module Agents

export step!, AbstractModel, AbstractAgent, batchrunner, data_collector,
move_agent!, add_agent!, get_node_contents, node_neighbors, nagents,
return_activation_order, random_activation, as_added, visualize_data, add_agent_single!,
move_agent_single!, kill_agent!,
write_to_file, visualize_2D_agent_distribution,
combine_columns!, partial_activation,
dummystep, visualize_1DCA, visualize_2DCA, batchrunner_parallel

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

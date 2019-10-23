module Agents

export batchrunner,
visualize_data,
visualize_2D_agent_distribution,
partial_activation,
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

include("core/model.jl")
include("core/space.jl")
include("core/agent_space_interaction.jl")
include("simulations/data_collector.jl")
include("simulations/step.jl")
include("simulations/batch_runner.jl")
include("visualization.jl")
# include("CA1D.jl")
# include("CA2D.jl")

end # module

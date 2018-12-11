module Agents

using LightGraphs
# using Distributions
using DataFrames
using VegaLite
using Random
import Base.Iterators: product
import StatsBase
using DataVoyager

include("agents_component.jl")
include("model_component.jl")
include("grids.jl")
include("scheduler.jl")
include("data_collector.jl")
include("batch_runner.jl")
include("visualization.jl")

# greet() = print("Hello World!")

end # module

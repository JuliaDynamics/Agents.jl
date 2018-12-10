module Agents

using LightGraphs
# using Distributions
using DataFrames
using VegaLite
using Random
# import Base.Iterators: product

include("agents_component.jl")
include("model_component.jl")
include("grids.jl")
include("scheduler.jl")
include("data_collector.jl")
include("batch_runner.jl")

greet() = print("Hello World!")

end # module

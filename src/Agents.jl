module Agents

using LightGraphs
using Distributions
using DataFrames
using VegaLite

include("agents_component.jl")
include("model_component.jl")

greet() = print("Hello World!")

end # module

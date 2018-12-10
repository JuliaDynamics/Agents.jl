module Agents

using LightGraphs
using Distributions
using DataFrames
using VegaLite
using Random
# import Base.Iterators: product

include("agents_component.jl")
include("model_component.jl")

greet() = print("Hello World!")

end # module

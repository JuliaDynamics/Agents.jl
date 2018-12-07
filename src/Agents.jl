module Agents

using LightGraphs
using Distributions

include("agents_component.jl")
include("model_component.jl")

greet() = print("Hello World!")

end # module

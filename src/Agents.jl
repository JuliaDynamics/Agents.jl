module Agents

using Distributed
using LightGraphs
using DataFrames
using Random
import Base.Iterators.product
import Base.iterate
import Base.length

# Core structures of Agents.jl
include("core/model.jl")
include("core/space.jl")
include("core/agent_space_interaction.jl")
include("core/continuous_space.jl")

# Stepping and data collection functionality
include("simulations/step.jl")
include("simulations/collect.jl")
include("simulations/paramscan.jl")
include("simulations/sample.jl")

# Auxilary
include("CA1D.jl")

end # module

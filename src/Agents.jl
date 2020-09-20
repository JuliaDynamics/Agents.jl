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
include("core/schedule.jl")
include("core/space_interaction_API.jl")

include("spaces/nothing.jl")
include("spaces/graph.jl")
include("spaces/grid.jl")
include("spaces/discrete.jl")
include("spaces/continuous_space.jl")

# Stepping and data collection functionality
include("simulations/step.jl")
include("simulations/collect.jl")
include("simulations/paramscan.jl")
include("simulations/sample.jl")

# Predefined models
include("models/Models.jl")
export Models

end # module

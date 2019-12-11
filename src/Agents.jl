module Agents

using Distributed
using LightGraphs
using DataFrames
using Dictionaries
using Random
import Base.Iterators.product
import Base.iterate
import Base.length

include("core/model.jl")
include("core/space.jl")
include("core/agent_space_interaction.jl")
include("simulations/data_collector.jl")
include("simulations/step.jl")
include("simulations/parallel.jl")
include("CA1D.jl")
include("CA2D.jl")

end # module

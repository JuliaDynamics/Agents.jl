export AgentsIO

"""
    AgentsIO

Submodule containing functionality for serialization and deserialization of model data
to and from files.
"""
module AgentsIO
using Agents

include("csv_integration.jl")
include("jld2_integration.jl")

end
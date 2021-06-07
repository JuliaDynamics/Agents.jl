export AgentsIO

"""
    AgentsIO
Submodule containing functionality for serialization and deserialization of model data
to and from files.

You can save and load agent data to and from CSV files using [`AgentsIO.dump_to_csv`](@ref)
and [`AgentsIO.populate_from_csv!`](@ref) respectively.
"""
module AgentsIO
using Agents

include("csv_integration.jl")
include("jld2_integration.jl")
end
export AgentsIO

"""
    AgentsIO
Submodule containing functionality for serialization and deserialization of model data
to and from files.

You can save and load agent data to and from CSV files using [`AgentsIO.dump_to_csv`](@ref)
and [`AgentsIO.populate_from_csv!`](@ref) respectively. Entire models can also be saved
to JLD2 files using [`AgentsIO.save_checkpoint`](@ref) and [`AgentsIO.load_checkpoint`](@ref).
"""
module AgentsIO
using Agents

include("csv_integration.jl")
include("jld2_integration.jl")
end
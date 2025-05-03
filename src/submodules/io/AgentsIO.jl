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

function dump_to_arrow end
function populate_from_arrow! end

end
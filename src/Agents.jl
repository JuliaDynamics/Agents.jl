module Agents

using Requires
using Distributed
using DataStructures
using Graphs
using DataFrames
using Random
import ProgressMeter

import Base.length
import LinearAlgebra

# Core structures of Agents.jl
include("core/agents.jl")
include("core/model.jl")
include("core/space_interaction_API.jl")

# Existing spaces
include("spaces/nothing.jl")
include("spaces/graph.jl")
include("spaces/grid.jl")
include("spaces/discrete.jl")
include("spaces/continuous.jl")
include("spaces/openstreetmap.jl")
include("spaces/utilities.jl")

# Stepping and data collection functionality
include("simulations/step.jl")
include("simulations/collect.jl")
include("simulations/paramscan.jl")
include("simulations/sample.jl")
include("simulations/ensemblerun.jl")

# Other features that exist in submodules
include("submodules/pathfinding/all_pathfinders.jl")
include("submodules/schedulers.jl")
include("submodules/io/AgentsIO.jl")
include("deprecations.jl")

# Predefined models
include("models/Models.jl")
export Models

# Update messages:
using Scratch
display_update = true
version_number = "4.6"
update_name = "update_v$(version_number)"

if display_update
    # Get scratch space for this package
    versions_dir = @get_scratch!("versions")
    if !isfile(joinpath(versions_dir, update_name))
        printstyled(
            stdout,
            """
            \nUpdate message: Agents v$(version_number)
            Please see the changelog online. Some key features:

            * Agents.jl now uses [Graphs.jl](https://github.com/JuliaGraphs/Graphs.jl) instead of LightGraphs.jl
            """;
            color = :light_magenta,
        )
        touch(joinpath(versions_dir, update_name))
    end
end

end # module

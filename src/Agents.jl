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
version_number = "4.5"
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

            * `get_spatial_property` and `get_spatial_index` functions have been added for easier usage of spatially distributed properties in `ContinuousSpace`.
            * The old pathfinding API has been deprecated in favour of a complete rework:
              Pathfinding structs are no longer stored by the space. Instead, `AStar` structs should be created by passing in the space and other parameters. All pathfinding functions now require the `AStar` struct to be passed in.
            * Pathfinding is now supported for `ContinuousSpace` using the A* algorithm.
            * Additional utility functions `nearby_walkable` and `random_walkable` for use with pathfinding.
            """;
            color = :light_magenta,
        )
        touch(joinpath(versions_dir, update_name))
    end
end

end # module

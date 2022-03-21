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
include("submodules/pathfinding/Pathfinding.jl")
include("submodules/schedulers.jl")
include("submodules/io/AgentsIO.jl")
include("models/Models.jl")

# Don't forget to update deprecations between versions!
include("deprecations.jl")

# Update messages:
using Scratch
display_update = true
version_number = "5"
update_name = "update_v$(version_number)"

function __init__()
if display_update
    # Get scratch space for this package
    versions_dir = @get_scratch!("versions")
    if !isfile(joinpath(versions_dir, update_name))
        printstyled(
            stdout,
            """
            \nUpdate message: Agents v$(version_number)
            Welcome to this new major version of Agents.jl!
            Noteworthy changes:

            * LightGraphs.jl dependency has been replaced by Graphs.jl.
              No change was done to `GraphSpace`, you only need to replace
              `using LightGraphs` with `using Graphs`.
            * The `OpenStreetMapSpace` now uses a new depedency, LightOSM.jl,
              which is much more performant than the previous OpenStreetMapX.jl.
              This meas that initializing a new space is slightly different, see
              the docstring of `OpenStreetMapSpace` for more.
            * Agents.jl + InteractiveDynamics.jl now support native plotting for
              open street map spaces, which is integrated in all interactive apps as well!
            * The majority of examples of the documentation have now moved to a new repository,
              JuliaDyamics/AgentsExampleZoo.jl. From now on, all additional examples
              will be hosted in that repo, to keep the main documentation lean.
            * Functions for planning and moving along routes have had their names
              unified across Pathfinding and OpenStreetMap modules. The names now are
              `plan_route!` and `move_along_route!` and are accessible from the top
              level scope.
            * See the CHANGELOG.md or online docs for more!
            """;
            color = :light_magenta,
        )
        touch(joinpath(versions_dir, update_name))
    end
end
end

end # module

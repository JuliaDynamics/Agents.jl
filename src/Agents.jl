module Agents

using StructArrays
using Requires
using Distributed
using DataStructures
using LightGraphs
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

function __init__()
    # Plot recipes
    @require Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80" begin
        include("visualization/plot-recipes.jl")
    end
    # Workaround for Documenter.jl, so we don't need to include
    # heavy dependencies to build documentation
    @require Documenter = "e30172f5-a6a5-5a46-863b-614d45cd2de4" begin
        include("visualization/plot-recipes.jl")
    end
end

# Deprecations, that will be removed in future versions
include("deprecated.jl")

# Predefined models
include("models/Models.jl")
export Models

# Update message:
display_update = true
version_number = "4.2"
update_name = "update_v$(version_number)"

if display_update
    if !isfile(joinpath(@__DIR__, update_name))
        printstyled(
            stdout,
            """
            \nUpdate message: Agents v$(version_number)
            Please see the changelog online. Some key features:

            * Self-contained features of Agents.jl will from now own exist in their own
              submodules. In the future, more features will be in submodules like this.
            * Full support for pathfinding, using the A* algorithm, in `GridSpace`
            * Several names have been reworked for more clarity (with deprecations)
            * New function `ensemblerun!` which replaces using `replicates` in `run!`
            * New documentation page "Performance Tips"
            * Parallelization of `paramscan`
            """;
            color = :light_magenta,
        )
        touch(joinpath(@__DIR__, update_name))
    end
end

end # module

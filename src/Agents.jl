module Agents

using Requires
using Distributed
using DataStructures
using LightGraphs
using DataFrames
using Random
using OpenStreetMapX
import ProgressMeter

import Base.length
import LinearAlgebra

# Core structures of Agents.jl
include("core/agents.jl")
include("core/model.jl")
include("core/schedule.jl")
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

# Other advanced features
include("pathfinding/grid_pathfinder.jl")

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

# 4.0 Depreciations
@deprecate space_neighbors nearby_ids
@deprecate node_neighbors nearby_positions
@deprecate get_node_contents ids_in_position
@deprecate get_node_agents agents_in_position
@deprecate pick_empty random_empty
@deprecate find_empty_nodes empty_positions
@deprecate has_empty_nodes has_empty_positions
@deprecate nodes positions

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

            * Full support for pathfinding, using the A* algorithm, in `GridSpace`
            * Scheduler names have been reworked for more clarity
            * New function `ensemblerun!` which replaces using `replicates` in `run!`
            * New documentation page "Performance Tips"
            """;
            color = :light_magenta,
        )
        touch(joinpath(@__DIR__, update_name))
    end
end

end # module

module Agents

using Requires
using Distributed
using DataStructures
using LightGraphs
using DataFrames
using Random
using OpenStreetMapX

import Base.length
import LinearAlgebra

# Core structures of Agents.jl
include("core/agents.jl")
include("core/model.jl")
include("core/schedule.jl")
include("core/space_interaction_API.jl")

include("spaces/pathfinding.jl")
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

include("pathfinding/grid_pathfinder.jl")

function __init__()
    # Plot recipes
    @require Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80" begin
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
version_number = "4.1"
update_name = "update_v$(version_number)"

if display_update
    if !isfile(joinpath(@__DIR__, update_name))
        printstyled(
            stdout,
            """
            \nUpdate message: Agents v$(version_number)

            `AgentBasedModel` now explicitly includes a random number generator, enabling
            reproducible ABM simulations with Agents.jl.
            Access it with `model.rng` and seed it with `seed!(model, seed)`!
            """;
            color = :light_magenta,
        )
        touch(joinpath(@__DIR__, update_name))
    end
end

end # module

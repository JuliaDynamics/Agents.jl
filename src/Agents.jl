module Agents

using Distributed
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

# Plot recipes
include("visualization/plot-recipes.jl")

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
version_number = "4.0"
update_name = "update_v$(version_number)"

if display_update
if !isfile(joinpath(@__DIR__, update_name))
printstyled(stdout,
"""
\nUpdate message: Agents v$(version_number)

Agents new release v$(version_number) is a massive one!
Notable features:
* Overhauled all spaces for more extendability, better performance, and more features
* New space type based on Open Street Map
* Renaming most of the API towards more intuitive names (deprecations exist!)
and more! See the full changelog online for a list of new features and breaking changes!

https://github.com/JuliaDynamics/Agents.jl/blob/master/CHANGELOG.md

"""; color = :light_magenta)
touch(joinpath(@__DIR__, update_name))
end
end

end # module

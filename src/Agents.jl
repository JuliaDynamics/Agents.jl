module Agents

using Distributed
using LightGraphs
using DataFrames
using Random
import Base.length

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
include("spaces/utilities.jl")

# Stepping and data collection functionality
include("simulations/step.jl")
include("simulations/collect.jl")
include("simulations/paramscan.jl")
include("simulations/sample.jl")

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

end # module

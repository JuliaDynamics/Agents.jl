module Agents

using Requires
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

include("deprecations.jl")

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

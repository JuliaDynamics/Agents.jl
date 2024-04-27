module Agents

# Use the README as the module docs
@doc let
    path = joinpath(dirname(@__DIR__), "README.md")
    include_dependency(path)
    read(path, String)
end Agents

using DataFrames
using DataStructures
using Distributed
using Graphs
using DataFrames
using MacroTools
using MixedStructTypes
export MixedStructTypes
import ProgressMeter
using Random
using StaticArrays: SVector
export SVector
import LinearAlgebra
import StreamSampling: itsample

# Core structures of Agents.jl
include("core/agents.jl")
include("core/model_abstract.jl")
include("core/model_free_extensions.jl")
include("core/model_standard.jl")
include("core/model_event_queue.jl")
include("core/model_validation.jl")
include("core/model_accessing_API.jl")
include("core/space_interaction_API.jl")
include("core/higher_order_iteration.jl")

# Existing spaces
include("spaces/nothing.jl")
include("spaces/graph.jl")
include("spaces/grid_general.jl")
include("spaces/grid_multi.jl")
include("spaces/grid_single.jl")
include("spaces/discrete.jl")
include("spaces/continuous.jl")
include("spaces/openstreetmap.jl")
include("spaces/utilities.jl")
include("spaces/walk.jl")

# Stepping and data collection functionality
include("simulations/step.jl")
include("simulations/step_standard.jl")
include("simulations/step_eventqueue.jl")
include("simulations/collect.jl")
include("simulations/paramscan.jl")
include("simulations/sample.jl")
include("simulations/ensemblerun.jl")

# Other features that exist in submodules
include("submodules/pathfinding/Pathfinding.jl")
include("submodules/schedulers.jl")
include("submodules/io/AgentsIO.jl")

# Don't forget to update deprecations between versions!
include("deprecations.jl")

# visualizations (singleton methods for package extension)
include("visualizations.jl")

include("precompile.jl")

# Update messages:
using Scratch

function __init__()
display_update = true
version_number = "6"
update_name = "update_v$(version_number)"
update_message = """
Update message: Agents v$(version_number)

This is a new major version of Agents.jl with lots of cool stuff!
However, from this version onwards, we will stop posting update messages
to the REPL console!

If you want to be updated, follow this discourse post:

https://discourse.julialang.org/t/agents-jl-v6-releases-announcement-post/111678

(and see the CHANGELOG.md file online for a list of changes!)
"""

if display_update
    # Get scratch space for this package
    versions_dir = @get_scratch!("versions")
    if !isfile(joinpath(versions_dir, update_name))
        printstyled(stdout, "\n"*update_message; color=:light_magenta)
        touch(joinpath(versions_dir, update_name))
    end
end
end # _init__ function.

end # module

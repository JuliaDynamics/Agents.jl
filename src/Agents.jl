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
using IteratorSampling
using MacroTools
using MixedStructTypes
export MixedStructTypes
import ProgressMeter
using Random
using StaticArrays: SVector
export SVector
import LinearAlgebra

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
Welcome to this new update of Agents.jl!
    
- A new `@multiagent` macro allows to run multi-agent simulations much more efficiently. It has
  two version: In `:opt_speed` the created agents are optimized such as there is virtually
  no performance difference between having 1 agent type at the cost of each agent occupying 
  more memory that in the `Union` case. In `:opt_memory` each agent is optimized to occupy practically 
  the same memory as the `Union` case, however this comes at a cost of performance versus having 1 type.
- A new experimental model type `EventQueueABM` has been implemented. It operates in continuous time through 
  the scheduling of events at arbitrary time points, in contrast with the discrete time nature of a `StandardABM`.
- Both the visualization and the model abstract interface have been refactored to improve the user
  experience to conform to the Agents.jl API when creating a new model type and its visualizations.
- The functions `agent_step!` and `model_step!` should now be passed as keyword arguments
  when a `StandardABM` is created. Passing those functions to the Agents.jl API functions
  which support them as argument is deprecated since now they are already available inside
  the model.
- A new `container` keyword can be passed during the model creation to decide the container
  type of the agents inside the model. By default it is equal to `Dict`. Passing `Vector` in 
  a `StandardABM` instead recreates the functionality of an `UnremovableABM`, so this model 
  type is deprecated. 
- The `@agent` macro is now THE way to create agent types for Agents.jl simulations since
  now supports declaring default and constant fields. Directly creating structs by hand is
  no longer mentioned in the documentation at all. This will allow us in the future to utilize
  additional fields that the user does not have to know about, which may bring new features or
  performance gains by being part of the agent structures. The macro has been rewritten to make it
  possible to declare fields as constants. The old version still works but it's deprecated.
  Refer to the documentation of the macro for the new syntax.
- Manually setting or altering the ids of agents is no longer allowed. The agent id is now considered
  a read-only field, and is set internally by Agents.jl to enable hidden optimizations in the future.
- `ContinuousAgent{D}` is not a concrete type anymore. The new interface requires two parameters
  `ContinuousAgent{D,T}` where `T` is any `AbstractFloat` type. If you want to use a type different
  from `Float64`, you will also need to change the type of the `ContinuousSpace` extent accordingly.
  Agents in `ContinuousSpace` now require `SVector` for their `pos` and `vel` fields instead of `NTuple`.
  Using `NTuple`s in `ContinuousSpace` is now deprecated.
- It is now possible to create a mixed-boundary `GridSpace`s which allows to mix periodic and non-periodic dimensions
  in a `GridSpace`.
- `Arrow` backend in `offline_run! is now supported` also for Windows users.
- Some new minor functionalities: `abmtime`, `swap_agents!`, `random_id_in_position`, `random_agent_in_position`.

See the online documentation for more!
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

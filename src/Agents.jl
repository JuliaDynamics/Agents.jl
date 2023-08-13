module Agents

# Use the README as the module docs
@doc let
    path = joinpath(dirname(@__DIR__), "README.md")
    include_dependency(path)
    read(path, String)
end Agents

using Distributed
using DataStructures
using Graphs
using DataFrames
using Random
using StaticArraysCore
import ProgressMeter
import Base.length # TODO: This should not be imported!!!
import LinearAlgebra

# Core structures of Agents.jl
include("core/agents.jl")
include("core/model_abstract.jl")
include("core/model_concrete.jl")
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
include("models/Models.jl")

# Don't forget to update deprecations between versions!
include("deprecations.jl")

# visualizations (singleton methods for package extension)
include("visualizations.jl")


# Update messages:
using Scratch

function __init__()
display_update = true
version_number = "5.18"
update_name = "update_v$(version_number)"
update_message = """
Update message: Agents v$(version_number)
Welcome to this new update of Agents.jl!

Noteworthy changes:

- Agents.jl moved to Julia 1.9+, and now exports visualization
  and interactive applications automatically once Makie (or Makie backends
  such as GLMakie) come into scope, using the new package extension system.
  The only downside of this is that now to visualize ABMs on open street
  maps, the package OSMMakie.jl must be explicitly loaded as well.
  InteractiveDynamics.jl is now obsolete.
- Several performance improvements all across the board.
- The `@agent` macro is now THE way to create agent types for Agents.jl simulations since
  now supports declaring default and constant fields. Directly creating structs by hand is 
  no longer mentioned in the documentation at all. This will allow us in the future to utilize
  additional fields that the user does not have to know about, which may bring new features or
  performance gains by being part of the agent structures.
- DEI-motivated name change for all names that remove agents:
    - `genocide! -> remove_all!`
    - `kill_agent! -> remove_agent!`
    - `UnkillableABM -> UnremovableABM`
- We have created an objective fully automated framework for comparing open source
  agent based modelling software. It shows that Agents.jl is much faster
  than competing alternatives (MASON, NetLogo, Mesa).

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

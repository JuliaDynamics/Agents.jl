module Agents

using Requires
using Distributed
using DataStructures
using Graphs
using DataFrames
using Random
import ProgressMeter
import Base.length # TODO: This should not be imported!!!
import LinearAlgebra

# Core structures of Agents.jl
include("core/agents.jl")
include("core/model.jl")
include("core/space_interaction_API.jl")

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

function __init__()
display_update = true
version_number = "5.5"
update_name = "update_v$(version_number)"
update_message = """
Update message: Agents v$(version_number)
Welcome to this new update of Agents.jl!
Noteworthy changes:

- The `@agent` macro has been re-written and is now more general and more safe.
  It now also allows inhereting fields from any other type.
- The `@agent` macro is now THE way to create agent types for Agents.jl simulations.
  Directly creating structs by hand is no longer mentioned in the documentation at all.
  This will allow us in the future to utilize additional fields that the user does not
  have to know about, which may bring new features or performance gains by being
  part of the agent structures.
- The minimal agent types like `GraphAgent` can be used normally as standard agent
  types that only have the mandatory fields. This is now clear in the docs.
  (this was possible also before v5.4, just not clear)
- In the future, making agent types by hand may be completely dissalowed, resulting
  in error. Therefore, making agent types manually is considered deprecated.
- New function `normalize_position`.

See the CHANGELOG.md, because v5.4 was also a large release!
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

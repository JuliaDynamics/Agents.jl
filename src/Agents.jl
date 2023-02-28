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

# Update messages:
using Scratch

function __init__()
display_update = true
version_number = "5.7"
update_name = "update_v$(version_number)"
update_message = """
Update message: Agents v$(version_number)
Welcome to this new update of Agents.jl!

Noteworthy changes:

- Internals of `AgentBasedModel` got reworked.
  It is now an abstract type, defining an abstract interface that concrete
  implementations may satisfy. This paves the way for flexibly defining new
  variants of `AgentBasedModel` that are more specialized in their applications.
- The old `AgentBasedModel` is now `StandardABM`
  Nothing is breaking because the call to `AgentBasedModel` gives `StandardABM`.
- Two new variants of agent based models: `UnkillableABM` and `FixedMassABM`.
  They yield huge performance benefits **(up to twice the speed!!!)**
  on iterating over agents if the agents can't get killed, or even added,
  during model evolution!
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

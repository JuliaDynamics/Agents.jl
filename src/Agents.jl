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
# include("models/Models.jl")

# Don't forget to update deprecations between versions!
include("deprecations.jl")

# Update messages:
using Scratch

function __init__()
display_update = true
version_number = "5.4"
update_name = "update_v$(version_number)"
update_message = """
Update message: Agents v$(version_number)
Welcome to this massive update of Agents.jl!
Noteworthy changes:

- About 5x performance increase in distributed computing!
- Internals of `GridSpace` have been completely re-written! This led to a significant
  performance increase of about 30%!
- New space `GridSpaceSingle` that is the same as `GridSpace` but only allows for one
  agent per position only. It utilizes this knowledge for massive performance benefits
  over `GridSpace`, **being about 3x faster than `GridSpace`** all across the board!
- Performance increase for nearby_stuff searches `ContinuousSpace` (2-5x faster)
- New `:manhattan` metric for `GridSpace` models!
- Several new deprecations and/or possible breaking changes!

See the CHANGELOG.md or online docs for more!
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

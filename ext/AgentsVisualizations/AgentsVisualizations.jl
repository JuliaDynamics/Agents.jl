module AgentsVisualizations

using Agents, Makie
# Pull API functions into extension module
using Agents: ABMObservable, space_axis_limits, agentsplot!
# using Agents: convert_element_pos, ids_to_inspect # For inspection, currently disabled

JULIADYNAMICS_COLORS = [
    "#7143E0",
    "#191E44",
    "#0A9A84",
    "#AF9327",
    "#791457",
    "#6C768C",
]
JULIADYNAMICS_CMAP = reverse(cgrad(:dense)[20:end])

include("src/model_observable.jl")
include("src/abmplot.jl")
include("src/utils.jl")

include("src/spaces/defaults.jl")
include("src/spaces/nothing.jl")
include("src/spaces/continuous.jl")
include("src/spaces/grid.jl")

include("src/interaction.jl")
include("src/convenience.jl")
include("src/deprecations.jl")

end

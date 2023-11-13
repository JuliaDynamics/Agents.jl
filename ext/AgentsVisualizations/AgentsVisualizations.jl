module AgentsVisualizations

using Agents, Makie
using Agents: AbstractGridSpace

JULIADYNAMICS_COLORS = [
    "#7143E0",
    "#191E44",
    "#0A9A84",
    "#AF9327",
    "#791457",
    "#6C768C",
]
JULIADYNAMICS_CMAP = reverse(cgrad(:dense)[20:end])

include("src/utils.jl")
include("src/model_observable.jl")
include("src/abmplot.jl")

# Spaces
include("src/spaces/discrete.jl")
include("src/spaces/continuous.jl")
include("src/spaces/grid.jl")
include("src/spaces/graph.jl")
include("src/spaces/openstreetmap.jl")

include("src/interaction.jl")
include("src/inspection.jl")
include("src/convenience.jl")
include("src/deprecations.jl")

end
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

include("src/abmplot.jl")
include("src/lifting.jl")
include("src/interaction.jl")
include("src/inspection.jl")
include("src/convenience.jl")
include("src/deprecations.jl")

end
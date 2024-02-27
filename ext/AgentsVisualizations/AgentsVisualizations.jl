module AgentsVisualizations

using Agents, Makie
using Agents: add_interaction!
# Pull API functions into extension module
using Agents: agents_space_dimensionality, get_axis_limits, agentsplot!
using Agents: spaceplot!, static_preplot!
using Agents: abmplot_heatobs, abmplot_pos, abmplot_colors, abmplot_markers, 
    abmplot_markersizes
using Agents: convert_element_pos, ids_to_inspect

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

include("src/spaces/abstract.jl")
include("src/spaces/nothing.jl")
include("src/spaces/continuous.jl")
include("src/spaces/grid.jl")

include("src/interaction.jl")
include("src/convenience.jl")
include("src/deprecations.jl")

end
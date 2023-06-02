module AgentsVisualizations

using Agents, Makie
using Agents: AbstractGridSpace

include("src/abmplot.jl")
include("src/lifting.jl")
include("src/interaction.jl")
include("src/inspection.jl")
include("src/convenience.jl")
include("src/deprecations.jl")

end
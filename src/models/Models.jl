"""
Sub-module of the module `Agents`, which contains pre-defined
agent based models shown the the Examples section of the documentation.
"""
module Models
using Agents

include("flocking.jl")
include("social_distancing.jl")
include("schelling.jl")
include("forestfire.jl")
include("wealth_distribution.jl")
include("hk.jl")
include("wright-fisher.jl")
include("daisyworld.jl")
include("predator_prey.jl")
include("growing_bacteria.jl")
include("game_of_life.jl")

end

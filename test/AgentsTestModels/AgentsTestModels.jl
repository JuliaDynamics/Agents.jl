"""
Module which contains pre-defined agent based models used for testing Agents.jl.

Models are represented by functions that initialize an ABM and return it.
"""
module AgentsTestModels
using Agents

include("daisyworld_def.jl")
include("flocking.jl")
include("schelling.jl")
include("sir.jl")
include("zombies.jl")
include("rabbit_fox_hawk.jl")

end

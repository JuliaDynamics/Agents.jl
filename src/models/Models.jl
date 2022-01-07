export Models

"""
Sub-module of the module `Agents`, which contains pre-defined
agent based models shown the the Examples section of the documentation.

Models are represented by functions that initialize an ABM, and return the ABM,
and the agent and model stepping functions.
"""
module Models
using Agents

include("flocking.jl")
include("schelling.jl")
include("sir.jl")
end

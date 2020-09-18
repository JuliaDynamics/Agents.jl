#=
This file implements functions shared by all discrete spaces.
Discrete spaces are by definition spaces with a finite amount of possible positions.
=#
const DiscreteSpace = Union{GraphSpace, GridSpace}

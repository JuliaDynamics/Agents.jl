export Pathfinding

"""
    Pathfinding
Submodule containing functionality for path-finding based on the A* algorithm.
Currently available only for [`GridSpace`](@ref).

You can enable path-finding and set it's options by passing an instance of a
[`Pathfinding.Pathfinder`](@ref) struct to the `pathfinder`
parameter of the [`GridSpace`](@ref) constructor. During the simulation, call
[`Pathfinding.set_target!`](@ref) to set the target destination for an agent.
This triggers the algorithm to calculate a path from the agent's current position to the one
specified. You can alternatively use [`Pathfinding.set_best_target!`](@ref) to choose the
best target from a list. Once a target has been set, you can move an agent one step along
its precalculated path using the [`move_along_route!`](@ref) function.

Refer to the [Maze Solver](@ref) and [Mountain Runners](@ref) examples using path-finding
and see the available functions below as well.
"""
module Pathfinding

using Agents
using DataStructures
using LinearAlgebra

include("metrics.jl")
include("grid_pathfinder.jl")

export CostMetric,
    DirectDistance,
    MaxDistance,
    HeightMap,
    AStar,
    delta_cost,
    set_target!,
    set_best_target!,
    heightmap,
    walkmap


end

export Pathfinding

"""
    Pathfinding
Submodule containing functionality for path-finding based on the A* algorithm.
Currently available for [`GridSpace`](@ref) and [`ContinuousSpace`](@ref).
Discretization of [`ContinuousSpace`](@ref) is taken care of internally.

You can enable path-finding and set its options by creating an instance of a
[`Pathfinding.AStar`](@ref) struct. This must be passed to the relevant pathfinding functions
during the simulation. Call [`Pathfinding.set_target!`](@ref) to set the target
destination for an agent. This triggers the algorithm to calculate a path from the agent's
current position to the one specified. You can alternatively use
[`Pathfinding.set_best_target!`](@ref) to choose the best target from a list. Once a target
has been set, you can move an agent one step along its precalculated path using the
[`move_along_route!`](@ref) function.

Refer to the [Maze Solver](@ref), [Mountain Runners](@ref) and [Rabbit, Fox, Hawk](@ref)
examples using path-finding and see the available functions below as well.
"""
module Pathfinding

using Agents
using DataStructures
using LinearAlgebra

"""
    Pathfinding.CostMetric{D}
An abstract type representing a metric that measures the approximate cost of travelling
between two points in a `D` dimensional grid.
"""
abstract type CostMetric{D} end

abstract type GridPathfinder{D,P,M} end

include("metrics.jl")
include("pathfinding_utils.jl")
include("astar.jl")
include("astar_grid.jl")
include("astar_continuous.jl")

export CostMetric,
    DirectDistance,
    MaxDistance,
    PenaltyMap,
    AStar,
    delta_cost,
    set_target!,
    set_best_target!,
    penaltymap,
    nearby_walkable,
    random_walkable

end

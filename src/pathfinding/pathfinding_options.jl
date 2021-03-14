export Pathfinder

abstract type AbstractPathfinder end
PathfinderType = Union{Nothing,AbstractPathfinder}

"""
    CostMetric{D}
An abstract type representing a metric that measures the approximate cost of travelling
between two points in a `D` dimensional [`GridSpace{D}`](@ref).
"""
abstract type CostMetric{D} end

struct Pathfinder{W<:Union{Array{Bool},Nothing}, M::Union{CostMetric, Nothing}}
    diagonal_movement::Bool
    admissibility::Float64
    walkable::W
    cost_metric::M
end

"""
    Pathfinder(; kwargs...)

Enable pathfinding using the A* algorithm by passing an instance of `Pathfinder` into
[`GridSpace`](@ref). Pathfinding works by using the functions
[`set_target!`](@ref) and [`move_along_route`](@ref) see [Path-finding](@ref) for more.

## Keywords

* `diagonal_movement = true` states that agents are allowed to move diagonally.
  Otherwise, only orthogonal directions are possible.
* `admissibility = 0` allows the algorithm to approximate paths to speed up pathfinding
  significantly. A value of `admissibility` allows paths at most `(1+admissibility)` times
  the optimal path length.
* `walkable = nothing` specifies (un)walkable regions of the space. If specified, it should
  be a boolean array of the same size as the corresponding [`GridSpace`](@ref). This defaults
  to `nothing`, which allows agents to walk on any position in the space. An example usage can
  be found in [Maze Solver](@ref).
* `cost_metric` is an instance of a cost metric and specifies the method
  to use for approximating the distance between two points. This defaults
  to [`DirectDistance`](@ref) with appropriate dimensionality.
"""
function Pathfinder(;
    diagonal_movement::Bool = true,
    admissibility::Float64 = 0.0,
    walkable::Union{Array{Bool},Nothing} = nothing,
    cost_metric::CostMetric = DirectDistance(),
)
    return Pathfinder(diagonal_movement, admissibility, walkable, cost_metric)
end

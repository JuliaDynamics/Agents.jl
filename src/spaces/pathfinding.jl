export Pathfinder

abstract type AbstractPathfinder end
PathfinderType = Union{Nothing,AbstractPathfinder}

"""
    CostMetric{D}
An abstract type representing a metric that measures the approximate cost of travelling
between two points in a `D` dimensional [`GridSpace{D}`](@ref).
"""
abstract type CostMetric{D} end

struct Pathfinder{M<:CostMetric}
    diagonal_movement::Bool
    admissibility::Float64
    walkable::Union{Array{Bool},Nothing}
    cost_metric::Union{M,Type{M}}
end

"""
    Pathfinder(; kwargs...)

Enable pathfinding using the A* algorithm by passing an instance of `Pathfinder` into
[`GridSpace`](@ref). Pathfinding parameters are tuned with the following keyword arguments:

* `diagonal_movement = true` states that agents are allowed to move diagonally. and allows agents to move to diagonally adjacent cells. If set to `false`,
agents are only allowed to move to adjacent neighbors.

`admissibility` allows the algorithm to approximate paths to speed up pathfinding significantly. A value of `ϵ`
allows paths atmost `(1+ϵ)` times the optimal path length. The default value is `0`, indicating that paths have
to be optimal.

`walkable` specifies (un)walkable regions of the space. If specified, it should be a boolean array of the same
dimensions and size as the corresponding [`GridSpace`](@ref). This defaults to `nothing`, which allows agents to walk on any
position in the space.

`cost_metric` specifies the method to use for approximating the distance between two points. This defaults
to [`DirectDistance`](@ref).
"""
Pathfinder(;
    diagonal_movement::Bool = true,
    admissibility::Float64 = 0.0,
    walkable::Union{Array{Bool},Nothing} = nothing,
    cost_metric::Union{Type{M},M} = DirectDistance,
) where {M<:CostMetric} =
    Pathfinder(diagonal_movement, admissibility, walkable, cost_metric)

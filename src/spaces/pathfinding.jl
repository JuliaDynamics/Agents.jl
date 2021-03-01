abstract type AbstractPathfinder end
PathfinderType = Union{Nothing,AbstractPathfinder}

"""
    CostMetric{D}
An abstract type representing a metric that measures the approximate cost of travelling
between two points in a `D` dimensional [`GridSpace{D}`](@ref).
"""
abstract type CostMetric{D} end

struct Pathfinder{M<:CostMetric}
    diagonal_neighbors::Bool
    admissibility::Float64
    walkable::Union{Array{Bool},Nothing}
    cost_metric::Union{M,Type{M}}
end

Pathfinder(;
    diagonal_neighbors::Bool = true,
    admissibility::Float64 = 0.0,
    walkable::Union{Array{Bool},Nothing} = nothing,
    cost_metric::Union{Type{M},M} = DirectDistance,
) where {M<:CostMetric} =
    Pathfinder(diagonal_neighbors, admissibility, walkable, cost_metric)

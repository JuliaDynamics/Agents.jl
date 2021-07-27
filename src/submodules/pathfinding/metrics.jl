"""
    Pathfinding.CostMetric{D}
An abstract type representing a metric that measures the approximate cost of travelling
between two points in a `D` dimensional [`GridSpace{D}`](@ref).
"""
abstract type CostMetric{D} end

struct DirectDistance{D} <: CostMetric{D}
    direction_costs::Vector{Int}
end

"""
    Pathfinding.DirectDistance{D}([direction_costs::Vector{Int}]) <: CostMetric{D}
Distance is approximated as the shortest path between the two points, provided the
`walkable` property of [`Pathfinding.AStar`](@ref) allows.
Optionally provide a `Vector{Int}` that represents the cost of going from a tile to the
neighboring tile on the `i` dimensional diagonal (default is `10√i`).

If `diagonal_movement=false` in [`Pathfinding.AStar`](@ref), neighbors in diagonal
positions will be excluded. Cost defaults to the first value of the provided vector.
"""
DirectDistance{D}() where {D} = DirectDistance{D}([floor(Int, 10.0 * √x) for x in 1:D])

Base.show(io::IO, metric::DirectDistance) = print(io, "DirectDistance")


"""
    Pathfinding.MaxDistance{D}() <: CostMetric{D}
Distance between two tiles is approximated as the maximum of absolute
difference in coordinates between them.
"""
struct MaxDistance{D} <: CostMetric{D} end

Base.show(io::IO, metric::MaxDistance) = print(io, "MaxDistance")

struct PenaltyMap{D} <: CostMetric{D}
    base_metric::CostMetric{D}
    pmap::Array{Int,D}
end

"""
    Pathfinding.PenaltyMap(pmap::Array{Int,D} [, base_metric::CostMetric]) <: CostMetric{D}
Distance between two positions is the sum of the shortest distance between them and the
absolute difference in penalty.

A penalty map (`pmap`) is required. For pathfinding in [`GridSpace`](@ref), this should be the
same dimensions as the space. For pathfinding in [`ContinuousSpace`](@ref), the size of this map
determines the granularity of the underlying grid, and should agree with the size of the
`walkable` map.

Distance is calculated using [`Pathfinding.DirectDistance`](@ref) by default, and can be
changed by specifying `base_metric`.

An example usage can be found in [Mountain Runners](@ref).
"""
PenaltyMap(pmap::Array{Int,D}) where {D} = PenaltyMap{D}(DirectDistance{D}(), pmap)

PenaltyMap(pmap::Array{Int,D}, base_metric::CostMetric{D}) where {D} =
    PenaltyMap{D}(base_metric, pmap)

Base.show(io::IO, metric::PenaltyMap) =
    print(io, "HeightMap with base: $(metric.base_metric)")

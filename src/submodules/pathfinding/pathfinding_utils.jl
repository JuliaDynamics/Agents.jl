"""
    Pathfinding.position_delta(pathfinder::AStar{D}, from::NTuple{Int,D}, to::NTuple{Int,D})
Returns the absolute difference in coordinates between `from` and `to` taking into account
periodicity of `pathfinder`.
"""
function position_delta(pathfinder::GridPathfinder{D,true}, from::Dims{D}, to::Dims{D}) where {D} 
    Δ = abs.(to .- from)
    walkmap_size = size(pathfinder.walkmap)
    if any(Δ .> walkmap_size)
        Δ = Δ .% walkmap_size
    end
    return Δ
end

position_delta(pathfinder::GridPathfinder{D,false}, from::Dims{D}, to::Dims{D}) where {D} =
    abs.(to .- from)

"""
    Pathfinding.delta_cost(pathfinder::GridPathfinder{D}, metric::M, from, to) where {M<:CostMetric}
Calculate an approximation for the cost of travelling from `from` to `to` (both of
type `NTuple{N,Int}`. Expects a return value of `Float64`.
"""
function delta_cost(
    pathfinder::GridPathfinder{D,periodic,true},
    metric::DirectDistance{D},
    from::Dims{D},
    to::Dims{D},
) where {D,periodic}
    delta = collect(position_delta(pathfinder, from, to))

    sort!(delta)
    carry = 0
    hdist = 0
    for i in D:-1:1
        hdist += metric.direction_costs[i] * (delta[D+1-i] - carry)
        carry = delta[D+1-i]
    end
    return hdist
end

function delta_cost(
    pathfinder::GridPathfinder{D,periodic,false},
    metric::DirectDistance{D},
    from::Dims{D},
    to::Dims{D},
) where {D,periodic}
    delta = position_delta(pathfinder, from, to)

    return sum(delta) * metric.direction_costs[1]
end

delta_cost(
    pathfinder::GridPathfinder{D},
    metric::MaxDistance{D},
    from::Dims{D},
    to::Dims{D},
) where {D} = max(position_delta(pathfinder, from, to)...)

delta_cost(
    pathfinder::GridPathfinder{D},
    metric::PenaltyMap{D},
    from::Dims{D},
    to::Dims{D},
) where {D} =
    delta_cost(pathfinder, metric.base_metric, from, to) +
    abs(metric.pmap[from...] - metric.pmap[to...])

delta_cost(pathfinder::GridPathfinder{D}, from::Dims{D}, to::Dims{D}) where {D} =
    delta_cost(pathfinder, pathfinder.cost_metric, from, to)

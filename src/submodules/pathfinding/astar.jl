"""
    Path{D}
Alias of `MutableLinkedList{Dims{D}}`. Used to represent the path to be
taken by an agent in a `D` dimensional [`GridSpace`](@ref).
"""
const Path{D} = MutableLinkedList{Dims{D}}

struct AStar{D,P,M}
    agent_paths::Dict{Int,Path{D}}
    grid_dims::Dims{D}
    neighborhood::Vector{CartesianIndex{D}}
    admissibility::Float64
    walkable::BitArray{D}
    cost_metric::CostMetric{D}

    function AStar{D,P,M}(
        agent_paths::Dict,
        grid_dims::Dims{D},
        neighborhood::Vector{CartesianIndex{D}},
        admissibility::Float64,
        walkable::BitArray{D},
        cost_metric::CostMetric{D},
    ) where {D,P,M}
        @assert size(walkable) == grid_dims "Walkmap must be same dimensions as grid"
        @assert admissibility >= 0 "Invalid value for admissibility: $admissibility ≱ 0"
        if cost_metric isa PenaltyMap{D}
            @assert size(cost_metric.pmap) == grid_dims "Penaltymap dimensions must be same as provided space"
        elseif cost_metric isa DirectDistance{D}
            if M
                @assert length(cost_metric.direction_costs) >= D "DirectDistance direction_costs must have as many values as dimensions"
            else
                @assert length(cost_metric.direction_costs) >= 1 "DirectDistance direction_costs must have non-zero length"
            end
        end
        new(agent_paths, grid_dims, neighborhood, admissibility, walkable, cost_metric)
    end
end

"""
    AStar(space::GridSpace{D}; kwargs...)
Enables pathfinding for agents in the provided `space` using the A* algorithm. This
struct must be passed into any pathfinding functions.

## Keywords
- `diagonal_movement = true` specifies if movement can be to diagonal neighbors of a
  tile, or only orthogonal neighbors.
- `admissibility = 0.0` allows the algorithm to aprroximate paths to speed up pathfinding.
  A value of `admissibility` allows paths with at most `(1+admissibility)` times the optimal
  length.
- `walkable = trues(size(space))` specifies the (un)walkable positions of the
  space. If specified, it should be a `BitArray` of the same size as the corresponding
  `GridSpace`. By default, agents can walk anywhere in the space. An example usage can
  be found in [Maze Solver](@ref)
- `cost_metric = DirectDistance{D}()` is an instance of a cost metric and specifies the
  metric used to approximate the distance between any two points. See [`CostMetric`](@ref).

Example usage in [Maze Solver](@ref) and [Mountain Runners](@ref).
"""
function AStar(
    dims::Dims{D};
    periodic::Bool = false,
    diagonal_movement::Bool = true,
    admissibility::Float64 = 0.0,
    walkable::BitArray{D} = trues(dims),
    cost_metric::CostMetric{D} = DirectDistance{D}(),
) where {D}
    neighborhood = diagonal_movement ? moore_neighborhood(D) : vonneumann_neighborhood(D)
    return AStar{D,periodic,diagonal_movement}(
        Dict{Int,Path{D}}(),
        dims,
        neighborhood,
        admissibility,
        walkable,
        cost_metric,
    )
end

AStar(
    space::GridSpace{D,periodic};
    diagonal_movement::Bool = true,
    admissibility::Float64 = 0.0,
    walkable::BitArray{D} = trues(size(space.s)),
    cost_metric::CostMetric{D} = DirectDistance{D}(),
) where {D,periodic} =
    AStar(size(space.s); periodic, diagonal_movement, admissibility, walkable, cost_metric)

moore_neighborhood(D) = [
    CartesianIndex(a)
    for a in Iterators.product([-1:1 for φ in 1:D]...) if a != Tuple(zeros(Int, D))
]

function vonneumann_neighborhood(D)
    hypercube = CartesianIndices((repeat([-1:1], D)...,))
    [β for β ∈ hypercube if LinearAlgebra.norm(β.I) == 1]
end

function Base.show(io::IO, pathfinder::AStar{D,P,M}) where {D,P,M}
    periodic = P ? "periodic, " : ""
    moore = M ? "diagonal, " : "orthogonal, "
    s =
        "A* in $(D) dimensions, $(periodic)$(moore)ϵ=$(pathfinder.admissibility), " *
        "metric=$(pathfinder.cost_metric)"
    print(io, s)
end

"""
    position_delta(pathfinder::AStar{D}, from::NTuple{Int,D}, to::NTuple{Int,D})
Returns the absolute difference in coordinates between `from` and `to` taking into account
periodicity of `pathfinder`.
"""
position_delta(pathfinder::AStar{D,true}, from::Dims{D}, to::Dims{D}) where {D} =
    min.(abs.(to .- from), pathfinder.grid_dims .- abs.(to .- from))

position_delta(pathfinder::AStar{D,false}, from::Dims{D}, to::Dims{D}) where {D} =
    abs.(to .- from)

"""
    delta_cost(pathfinder::AStar{D}, metric::M, from, to) where {M<:CostMetric}
Calculate an approximation for the cost of travelling from `from` to `to` (both of
type `NTuple{N,Int}`. Expects a return value of `Float64`.
"""
function delta_cost(
    pathfinder::AStar{D,periodic,true},
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
    pathfinder::AStar{D,periodic,false},
    metric::DirectDistance{D},
    from::Dims{D},
    to::Dims{D},
) where {D,periodic}
    delta = position_delta(pathfinder, from, to)

    return sum(delta) * metric.direction_costs[1]
end

delta_cost(
    pathfinder::AStar{D},
    metric::MaxDistance{D},
    from::Dims{D},
    to::Dims{D},
) where {D} = max(position_delta(pathfinder, from, to)...)

delta_cost(
    pathfinder::AStar{D},
    metric::PenaltyMap{D},
    from::Dims{D},
    to::Dims{D},
) where {D} =
    delta_cost(pathfinder, metric.base_metric, from, to) +
    abs(metric.pmap[from...] - metric.pmap[to...])

delta_cost(pathfinder::AStar{D}, from::Dims{D}, to::Dims{D}) where {D} =
    delta_cost(pathfinder, pathfinder.cost_metric, from, to)

struct GridCell
    f::Int
    g::Int
    h::Int
end

GridCell(g::Int, h::Int, admissibility::Float64) =
    GridCell(round(Int, g + (1 + admissibility) * h), g, h)

GridCell() = GridCell(typemax(Int), typemax(Int), typemax(Int))

"""
    find_path(pathfinder::AStar{D}, from::NTuple{D,Int}, to::NTuple{D,Int})
Calculate the shortest path from `from` to `to` using the A* algorithm.
If a path does not exist between the given positions, an empty linked list is returned.
"""
function find_path(pathfinder::AStar{D}, from::Dims{D}, to::Dims{D}) where {D}
    grid = Dict{Dims{D},GridCell}()
    parent = Dict{Dims{D},Dims{D}}()

    open_list = MutableBinaryMinHeap{Tuple{Int,Dims{D}}}()
    open_list_handles = Dict{Dims{D},Int64}()
    closed_list = Set{Dims{D}}()

    grid[from] = GridCell(0, delta_cost(pathfinder, from, to), pathfinder.admissibility)
    push!(open_list, (grid[from].f, from))

    while !isempty(open_list)
        _, cur = pop!(open_list)
        cur == to && break
        push!(closed_list, cur)

        nbors = get_neighbors(cur, pathfinder)
        for nbor in Iterators.filter(n -> inbounds(n, pathfinder, closed_list), nbors)
            nbor_cell = haskey(grid, nbor) ? grid[nbor] : GridCell()
            new_g_cost = grid[cur].g + delta_cost(pathfinder, cur, nbor)

            if new_g_cost < nbor_cell.g
                parent[nbor] = cur
                grid[nbor] = GridCell(
                    new_g_cost,
                    delta_cost(pathfinder, nbor, to),
                    pathfinder.admissibility,
                )
                if haskey(open_list_handles, nbor)
                    update!(open_list, open_list_handles[nbor], (grid[nbor].f, nbor))
                else
                    open_list_handles[nbor] = push!(open_list, (grid[nbor].f, nbor))
                end
            end
        end
    end

    agent_path = Path{D}()
    cur = to
    while true
        haskey(parent, cur) || break
        pushfirst!(agent_path, cur)
        cur = parent[cur]
    end
    return agent_path
end

@inline get_neighbors(cur, pathfinder::AStar{D,true}) where {D} =
    (mod1.(cur .+ β.I, pathfinder.grid_dims) for β in pathfinder.neighborhood)
@inline get_neighbors(cur, pathfinder::AStar{D,false}) where {D} =
    (cur .+ β.I for β in pathfinder.neighborhood)
@inline inbounds(n, pathfinder, closed) =
    all(1 .<= n .<= pathfinder.grid_dims) && pathfinder.walkable[n...] && n ∉ closed
    
Base.isempty(id::Int, pathfinder::AStar) =
    !haskey(pathfinder.agent_paths, id) || isempty(pathfinder.agent_paths[id])

Agents.is_stationary(
    agent::A,
    pathfinder::AStar,
) where {A<:AbstractAgent} = isempty(agent.id, pathfinder)

"""
    Pathfinding.penaltymap(pathfinder)
Return the penaltymap of a [`Pathfinding.AStar`](@ref) if the
[`Pathfinding.PenaltyMap`](@ref) metric is in use, `nothing` otherwise.

It is possible to mutate the map directly, for example
`Pathfinding.penaltymap(pathfinder)[15, 40] = 115`
or `Pathfinding.penaltymap(pathfinder) .= rand(50, 50)`. If this is mutated,
a new path needs to be planned using [`Pathfinding.set_target!`](@ref).
"""
function penaltymap(pathfinder::AStar)
    if pathfinder.cost_metric isa PenaltyMap
        return pathfinder.cost_metric.pmap
    else
        return nothing
    end
end

"""
    kill_agent!(agent, model, pathfinder)
The same as `kill_agent!(agent, model)`, but also removes the agent's path data
from `pathfinder`.
"""
function Agents.kill_agent!(
    agent::A,
    model::ABM{S,A},
    pathfinder::AStar,
) where {S,A<:AbstractAgent}
    delete!(pathfinder.agent_paths, agent.id)
    delete!(model.agents, agent.id)
    Agents.remove_agent_from_space!(agent, model)
end

"""
    nearby_walkable(position, model, pathfinder, r = 1)
Returns an iterable of all [`nearby_positions`](@ref) within "radius" `r` of the given
`position` (excluding `position`), which are walkable as specified by the given `pathfinder`.
"""
nearby_walkable(position, model, pathfinder, r = 1) =
    Iterators.filter(x -> pathfinder.walkable[x...] == 1, nearby_positions(position, model, r))
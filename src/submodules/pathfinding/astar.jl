"""
    Path{D,T}
Alias of `MutableLinkedList{NTuple{D,T}}`. Used to represent the path to be
taken by an agent in a `D` dimensional space.
"""
const Path{D,T} = MutableLinkedList{NTuple{D,T}}

struct AStar{D,P,M,T,C<:CostMetric{D}} <: GridPathfinder{D,P,M}
    agent_paths::Dict{Int,Path{D,T}}
    dims::NTuple{D,T}
    neighborhood::Vector{CartesianIndex{D}}
    admissibility::Float64
    walkmap::BitArray{D}
    cost_metric::C

    function AStar{D,P,M,T,C}(
        agent_paths::Dict,
        dims::NTuple{D,T},
        neighborhood::Vector{CartesianIndex{D}},
        admissibility::Float64,
        walkmap::BitArray{D},
        cost_metric::C,
    ) where {D,P,M,C,T}
        @assert all(dims .> 0) "Invalid pathfinder dimensions: $(dims)"
        T <: Integer && @assert size(walkmap) == dims "Walkmap must be same dimensions as grid"
        @assert admissibility >= 0 "Invalid value for admissibility: $admissibility ≱ 0"
        if cost_metric isa PenaltyMap{D}
            @assert size(cost_metric.pmap) == size(walkmap) "Penaltymap dimensions must be same as walkable map"
        elseif cost_metric isa DirectDistance{D}
            if M
                @assert length(cost_metric.direction_costs) >= D "DirectDistance direction_costs must have as many values as dimensions"
            else
                @assert length(cost_metric.direction_costs) >= 1 "DirectDistance direction_costs must have non-zero length"
            end
        end
        new(agent_paths, dims, neighborhood, admissibility, walkmap, cost_metric)
    end
end

"""
    Pathfinding.AStar(space; kwargs...)
Enables pathfinding for agents in the provided `space` (which can be a [`GridSpace`](@ref) or
[`ContinuousSpace`](@ref)) using the A* algorithm. This struct must be passed into any
pathfinding functions.

For [`ContinuousSpace`](@ref), a walkmap or instance of [`PenaltyMap`](@ref) must be provided
to specify the level of discretisation of the space.

## Keywords
- `diagonal_movement = true` specifies if movement can be to diagonal neighbors of a
  tile, or only orthogonal neighbors. Only available for [`GridSpace`](@ref)
- `admissibility = 0.0` allows the algorithm to approximate paths to speed up pathfinding.
  A value of `admissibility` allows paths with at most `(1+admissibility)` times the optimal
  length.
- `walkmap = trues(size(space))` specifies the (un)walkable positions of the
  space. If specified, it should be a `BitArray` of the same size as the corresponding
  `GridSpace`. By default, agents can walk anywhere in the space.
- `cost_metric = DirectDistance{D}()` is an instance of a cost metric and specifies the
  metric used to approximate the distance between any two points.

Utilization of all features of `AStar` occurs in the
[3D Mixed-Agent Ecosystem with Pathfinding](@ref) example.
"""
function AStar(
    dims::NTuple{D,T};
    periodic::Union{Bool,NTuple{D,Bool}} = false,
    diagonal_movement::Bool = true,
    admissibility::Float64 = 0.0,
    walkmap::BitArray{D} = trues(dims),
    cost_metric::CostMetric{D} = DirectDistance{D}(),
) where {D,T}
    neighborhood = diagonal_movement ? moore_neighborhood(D) : vonneumann_neighborhood(D)
    return AStar{D,periodic,diagonal_movement,T,typeof(cost_metric)}(
        Dict{Int,Path{D,T}}(),
        dims,
        neighborhood,
        admissibility,
        walkmap,
        cost_metric,
    )
end

AStar(
    space::GridSpace{D,periodic};
    diagonal_movement::Bool = true,
    admissibility::Float64 = 0.0,
    walkmap::BitArray{D} = trues(size(space)),
    cost_metric::CostMetric{D} = DirectDistance{D}(),
) where {D,periodic} =
    AStar(size(space); periodic, diagonal_movement, admissibility, walkmap, cost_metric)

function AStar(
    space::ContinuousSpace{D,periodic};
    walkmap::Union{BitArray{D},Nothing} = nothing,
    admissibility::Float64 = 0.0,
    cost_metric::CostMetric{D} = DirectDistance{D}(),
) where {D,periodic}
    @assert walkmap isa BitArray{D} || cost_metric isa PenaltyMap "Pathfinding in ContinuousSpace requires either walkmap to be specified or cost_metric to be a PenaltyMap"
    isnothing(walkmap) && (walkmap = BitArray(trues(size(cost_metric.pmap))))
    AStar(Tuple(Agents.spacesize(space));
        periodic, diagonal_movement = true,
        admissibility, walkmap, cost_metric
    )
end


moore_neighborhood(D) = [
    CartesianIndex(a)
    for a in Iterators.product([-1:1 for φ in 1:D]...) if a != Tuple(zeros(Int, D))
]

function vonneumann_neighborhood(D)
    hypercube = CartesianIndices((repeat([-1:1], D)...,))
    [β for β ∈ hypercube if LinearAlgebra.norm(β.I) == 1]
end

function Base.show(io::IO, pathfinder::AStar{D,P,M}) where {D,P,M}
    periodic = get_periodic_type(pathfinder)
    moore = M ? "diagonal, " : "orthogonal, "
    s =
        "A* in $(D) dimensions, $(periodic)$(moore)ϵ=$(pathfinder.admissibility), " *
        "metric=$(pathfinder.cost_metric)"
    print(io, s)
end
get_periodic_type(::AStar{D,false,M}) where {D,M} = ""
get_periodic_type(::AStar{D,true,M}) where {D,M} = "periodic, "
get_periodic_type(::AStar{D,P,M}) where {D,P,M} = "mixed periodicity, "

struct GridCell
    f::Int
    g::Int
    h::Int
end

GridCell(g::Int, h::Int, admissibility::Float64) =
    GridCell(round(Int, g + (1 + admissibility) * h), g, h)

GridCell() = GridCell(typemax(Int), typemax(Int), typemax(Int))

ordering(cell) = cell.f

"""
    find_path(pathfinder::AStar{D}, from::NTuple{D,Int}, to::NTuple{D,Int})
Calculate the shortest path from `from` to `to` using the A* algorithm.
If a path does not exist between the given positions, an empty linked list is returned.
"""
function find_path(pathfinder::AStar{D}, from::Dims{D}, to::Dims{D}) where {D}
    if !all(1 .<= from .<= size(pathfinder.walkmap)) ||
        !all(1 .<= to .<= size(pathfinder.walkmap)) ||
        !pathfinder.walkmap[from...] ||
        !pathfinder.walkmap[to...]
        return # nothing
    end
    parent = Dict{Dims{D},Dims{D}}()

    open_list = PriorityQueue{Dims{D},GridCell}(Base.By(ordering))
    closed_list = Set{Dims{D}}()

    enqueue!(
        open_list,
        from,
        GridCell(0, delta_cost(pathfinder, from, to), pathfinder.admissibility)
    )

    while !isempty(open_list)
        cur, cell = dequeue_pair!(open_list)
        cur == to && break
        push!(closed_list, cur)

        nbors = get_neighbors(cur, pathfinder)
        for nbor in Iterators.filter(n -> inbounds(n, pathfinder, closed_list), nbors)
            nbor_cell = haskey(open_list, nbor) ? open_list[nbor] : GridCell()
            new_g_cost = cell.g + delta_cost(pathfinder, cur, nbor)

            if new_g_cost < nbor_cell.g
                parent[nbor] = cur
                open_list[nbor] = GridCell(
                    new_g_cost,
                    delta_cost(pathfinder, nbor, to),
                    pathfinder.admissibility,
                )
            end
        end
    end

    agent_path = Path{D,Int64}()
    cur = to
    while true
        haskey(parent, cur) || break
        pushfirst!(agent_path, cur)
        cur = parent[cur]
    end
    cur == from || return # nothing
    return agent_path
end

@inline get_neighbors(cur, pathfinder::AStar{D,true}) where {D} =
    (mod1.(cur .+ β.I, size(pathfinder.walkmap)) for β in pathfinder.neighborhood)
@inline get_neighbors(cur, pathfinder::AStar{D,false}) where {D} =
    (cur .+ β.I for β in pathfinder.neighborhood)
@inline function get_neighbors(cur, pathfinder::AStar{D,P}) where {D,P}
    s = size(pathfinder.walkmap)
    (
        ntuple(i -> P[i] ? mod1(cur[i] + β[i], s[i]) : cur[i] + β[i], D)
        for β in pathfinder.neighborhood
    )
end
@inline inbounds(n, pathfinder, closed) =
    all(1 .<= n .<= size(pathfinder.walkmap)) && pathfinder.walkmap[n...] && n ∉ closed

Base.isempty(id::Int, pathfinder::AStar) =
    !haskey(pathfinder.agent_paths, id) || isempty(pathfinder.agent_paths[id])

"""
    is_stationary(agent, astar::AStar)
Same, but for pathfinding with A*.
"""
Agents.is_stationary(
    agent::A,
    pathfinder::AStar,
) where {A<:AbstractAgent} = isempty(agent.id, pathfinder)

"""
    Pathfinding.penaltymap(pathfinder)
Return the penalty map of a [`Pathfinding.AStar`](@ref) if the
[`Pathfinding.PenaltyMap`](@ref) metric is in use, `nothing` otherwise.

It is possible to mutate the map directly, for example
`Pathfinding.penaltymap(pathfinder)[15, 40] = 115`
or `Pathfinding.penaltymap(pathfinder) .= rand(50, 50)`. If this is mutated,
a new path needs to be planned using [`plan_route!`](@ref).
"""
function penaltymap(pathfinder::AStar)
    if pathfinder.cost_metric isa PenaltyMap
        return pathfinder.cost_metric.pmap
    else
        return nothing
    end
end

"""
    Pathfinding.remove_agent!(agent, model, pathfinder)
The same as `remove_agent!(agent, model)`, but also removes the agent's path data
from `pathfinder`.
"""
function Agents.remove_agent!(
    agent::A,
    model::ABM{S,A},
    pathfinder::AStar,
) where {S,A<:AbstractAgent}
    delete!(pathfinder.agent_paths, agent.id)
    Agents.remove_agent_from_model!(agent, model)
    Agents.remove_agent_from_space!(agent, model)
end

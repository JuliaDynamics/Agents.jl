"""
    Path{D,T}
Alias of `MutableLinkedList{NTuple{D,T}}`. Used to represent the path to be
taken by an agent in a `D` dimensional space.
"""
const Path{D,T} = MutableLinkedList{NTuple{D,T}}

struct AStar{D,P,M,T} <: GridPathfinder{D,P,M}
    agent_paths::Dict{Int,Path{D,T}}
    dims::NTuple{D,T}
    neighborhood::Vector{CartesianIndex{D}}
    admissibility::Float64
    walkable::BitArray{D}
    cost_metric::CostMetric{D}

    function AStar{D,P,M,T}(
        agent_paths::Dict,
        dims::NTuple{D,T},
        neighborhood::Vector{CartesianIndex{D}},
        admissibility::Float64,
        walkable::BitArray{D},
        cost_metric::CostMetric{D},
    ) where {D,P,M,T}
        @assert all(dims .> 0) "Invalid pathfinder dimensions: $(dims)"
        T <: Integer && @assert size(walkable) == dims "Walkmap must be same dimensions as grid"
        @assert admissibility >= 0 "Invalid value for admissibility: $admissibility ≱ 0"
        if cost_metric isa PenaltyMap{D}
            @assert size(cost_metric.pmap) == size(walkable) "Penaltymap dimensions must be same as walkable map"
        elseif cost_metric isa DirectDistance{D}
            if M
                @assert length(cost_metric.direction_costs) >= D "DirectDistance direction_costs must have as many values as dimensions"
            else
                @assert length(cost_metric.direction_costs) >= 1 "DirectDistance direction_costs must have non-zero length"
            end
        end
        new(agent_paths, dims, neighborhood, admissibility, walkable, cost_metric)
    end
end

"""
    Pathfinding.AStar(space::GridSpace{D}; kwargs...)
    Pathfinding.AStar(space::ContinuousSpace{D}, walkmap::BitArray{D}; kwargs...)
    Pathfinding.AStar(space::ContinuousSpace{D}, cost_metric::PenaltyMap{D}; kwargs...)
Enables pathfinding for agents in the provided `space` (which can be a [`GridSpace`](@ref) or
[`ContinuousSpace`](@ref)) using the A* algorithm. This struct must be passed into any
pathfinding functions.

For [`ContinuousSpace`](@ref), a walkmap or instance of [`PenaltyMap`](@ref) must be provided
to specify the level of discretisation of the space.

## Keywords
- `diagonal_movement = true` specifies if movement can be to diagonal neighbors of a
  tile, or only orthogonal neighbors. Only available for [`GridSpace`](@ref)
- `admissibility = 0.0` allows the algorithm to aprroximate paths to speed up pathfinding.
  A value of `admissibility` allows paths with at most `(1+admissibility)` times the optimal
  length.
- `walkable = trues(size(space))` specifies the (un)walkable positions of the
  space. If specified, it should be a `BitArray` of the same size as the corresponding
  `GridSpace`. By default, agents can walk anywhere in the space. An example usage can
  be found in [Maze Solver](@ref)
- `cost_metric = DirectDistance{D}()` is an instance of a cost metric and specifies the
  metric used to approximate the distance between any two points. See [`CostMetric`](@ref).
  An example usage can be found in [Mountain Runners](@ref).
"""
function AStar{T}(
    dims::NTuple{D,T};
    periodic::Bool = false,
    diagonal_movement::Bool = true,
    admissibility::Float64 = 0.0,
    walkable::BitArray{D} = trues(dims),
    cost_metric::CostMetric{D} = DirectDistance{D}(),
) where {D,T}
    neighborhood = diagonal_movement ? moore_neighborhood(D) : vonneumann_neighborhood(D)
    return AStar{D,periodic,diagonal_movement,T}(
        Dict{Int,Path{D,T}}(),
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
    AStar{Int64}(size(space); periodic, diagonal_movement, admissibility, walkable, cost_metric)

AStar(
    space::ContinuousSpace{D,periodic},
    walkable::BitArray{D};
    admissibility::Float64 = 0.0,
    cost_metric::CostMetric{D} = DirectDistance{D}(),
) where {D,periodic} =
    AStar{Float64}(size(space); periodic, diagonal_movement = true, admissibility, walkable, cost_metric)

AStar(
    space::ContinuousSpace{D,periodic},
    cost_metric::PenaltyMap{D};
    walkable::BitArray{D} = trues(size(cost_metric.pmap)),
    admissibility::Float64 = 0.0,
) where {D,periodic} =
    AStar{Float64}(size(space); periodic, diagonal_movement = true, admissibility, walkable, cost_metric)


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
    (mod1.(cur .+ β.I, size(pathfinder.walkable)) for β in pathfinder.neighborhood)
@inline get_neighbors(cur, pathfinder::AStar{D,false}) where {D} =
    (cur .+ β.I for β in pathfinder.neighborhood)
@inline inbounds(n, pathfinder, closed) =
    all(1 .<= n .<= size(pathfinder.walkable)) && pathfinder.walkable[n...] && n ∉ closed
    
Base.isempty(id::Int, pathfinder::AStar) =
    !haskey(pathfinder.agent_paths, id) || isempty(pathfinder.agent_paths[id])

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

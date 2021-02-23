export CostMetric,
    DirectDistance, Chebyshev, HeightMap, AStar, delta_cost, find_path, set_target!

"""
    Path{D}
An alias for `MutableLinkedList{Dims{D}}`. Used to represent the path to be
taken by an agent in a `D` dimensional [`GridSpace{D}`](@ref).
"""
const Path{D} = MutableLinkedList{Dims{D}}

"""
    CostMetric{D}
An abstract type representing a metric that measures the approximate cost of travelling
between two points in a `D` dimensional [`GridSpace{D}`](@ref). A struct with this as its
base type is used as the `cost_metric` for [`AStar`](@ref). To define a custom metric,
define a struct with this as its base type and a corresponding method for [`delta_cost`](@ref).
"""
abstract type CostMetric{D} end

struct DirectDistance{D} <: CostMetric{D}
    direction_costs::Vector{Int}
end

function Base.show(io::IO, metric::DirectDistance{D}) where {D}
    s = "DirectDistance metric"
    print(io, s)
end

"""
    DirectDistance{D}(direction_costs::Vector{Int}=[floor(Int, 10.0*√x) for x in 1:D])
The default cost metric for [`AStar`](@ref). Distance is approximated as the shortest path between
the two points, where from any tile it is possible to step to any of its Moore neighbors.
`direction_costs` is an `Array{Int,1}` where `direction_costs[i]` represents the cost of
going from a tile to the neighbording tile on the `i` dimensional diagonal. The default value is
`10√i` for the `i` dimensional diagonal, rounded down to the nearest integer.

If `moore_neighbors=false` in the [`AStar`](@ref) struct, then it is only possible to step to
VonNeumann neighbors.
"""
DirectDistance{D}() where {D} = DirectDistance{D}([floor(Int, 10.0 * √x) for x in 1:D])

"""
    Chebyshev{D}()
Distance between two tiles is approximated as the Chebyshev distance (maximum of absolute
difference in coordinates) between them.
"""
struct Chebyshev{D} <: CostMetric{D} end

function Base.show(io::IO, metric::Chebyshev{D}) where {D}
    s = "Chebyshev metric"
    print(io, s)
end

struct HeightMap{D} <: CostMetric{D}
    base_metric::CostMetric{D}
    hmap::Array{Int,D}
end

function Base.show(io::IO, metric::HeightMap{D}) where {D}
    s = "HeightMap metric with base_metric=$(metric.base_metric)"
    print(io, s)
end

"""
    HeightMap(hmap::Array{Int,D})
An alternative [`CostMetric{D}`](@ref). This allows for a `D` dimensional heightmap to be provided as a
`D` dimensional integer array, of the same size as the corresponding [`GridSpace{D}`](@ref). This metric
approximates the distance between two positions as the sum of the shortest distance between them and the absolute
difference in heights between the two positions. The shortest distance is calculated using the underlying
`base_metric` field, which defaults to [`DirectDistance{D}`](@ref)
"""
HeightMap(hmap::Array{Int,D}) where {D} = HeightMap{D}(DirectDistance{D}(), hmap)

struct AStar{D,P,M} <: AbstractPathfinder
    agent_paths::Dict{Int,Path{D}}
    grid_dims::Dims{D}
    neighborhood::Vector{CartesianIndex{D}}
    admissibility::AbstractFloat
    walkable::Array{Bool,D}
    cost_metric::CostMetric{D}
end

"""
    AStar(space::GridSpace; kwargs...)
Stores path data of agents, and relevant pathfinding grid data. The dimensions are taken to be those of the space.

Keyword Arguments:
- `moore_neighbors::Bool=true` specifies if movement can be to Moore neighbors of a tile, or only
Von Neumann neighbors. Correspondingly affects how [`DirectDistance{D}`](@ref) is calculated.

- `admissibility::AbstractFloat=0.0` specifies how much a path can deviate from optimality, in favour
of faster pathfinding. For an admissibility value of `ε`, a path with at most `(1+ε)` times the optimal path length
will be calculated, exploring fewer nodes in the process. A value of `0` always finds the optimal path.

- `walkable::Array{Bool,D}=fill(true, size(space.s))` is used to specify (un)walkable positions of
the space. Unwalkable positions are never part of any paths. By default, all positions are assumed to be walkable.

- `cost_metric::CostMetric{D}=DirectDistance{D}()` specifies the metric used to approximate
the distance between any two walkable points on the grid.
"""
function AStar(
    space::GridSpace{D,P};
    moore_neighbors::Bool = true,
    admissibility::AbstractFloat = 0.0,
    walkable::Array{Bool,D} = fill(true, size(space.s)),
    cost_metric::CostMetric{D} = DirectDistance{D}(),
) where {D,P}

    neighborhood = moore_neighbors ? moore_neighborhood(D) : vonneumann_neighborhood(D)
    return AStar{D,P,moore_neighbors}(
        Dict{Int,Path{D}}(),
        size(space.s),
        neighborhood,
        admissibility,
        walkable,
        cost_metric,
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
    s = "A* in $(D) dimensions\nperiodic=$(P)\nmoore=$(M)\nadmissibility=$(pathfinder.admissibility)\nmetric=$(pathfinder.cost_metric)"
    print(io, s)
end

"""
    position_delta(pathfinder::AStar{D}, from::NTuple{Int,D}, to::NTuple{Int,D})
Returns the absolute difference in coordinates between `from` and `to` taking into account periodicity of `pathfinder`.
"""
position_delta(pathfinder::AStar{D,true}, from::Dims{D}, to::Dims{D}) where {D} =
    min.(abs.(to .- from), pathfinder.grid_dims .- abs.(to .- from))

position_delta(pathfinder::AStar{D,false}, from::Dims{D}, to::Dims{D}) where {D} =
    abs.(to .- from)

"""
    delta_cost(pathfinder::AStar{D}, from::NTuple{D, Int}, to::NTuple{D, Int})
Calculates and returns an approximation for the cost of travelling from `from` to `to`. This calls the corresponding
`delta_cost(pathfinder, pathfinder.cost_metric, from, to)` function. In the case of a custom metric, define a method for
the latter function.
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
    metric::Chebyshev{D},
    from::Dims{D},
    to::Dims{D},
) where {D} = max(position_delta(pathfinder, from, to)...)

delta_cost(
    pathfinder::AStar{D},
    metric::HeightMap{D},
    from::Dims{D},
    to::Dims{D},
) where {D} =
    delta_cost(pathfinder, metric.base_metric, from, to) +
    abs(metric.hmap[from...] - metric.hmap[to...])

delta_cost(pathfinder::AStar{D}, from::Dims{D}, to::Dims{D}) where {D} =
    delta_cost(pathfinder, pathfinder.cost_metric, from, to)

struct GridCell
    f::Int
    g::Int
    h::Int
end

GridCell(g::Int, h::Int, admissibility::AbstractFloat) =
    GridCell(round(Int, g + (1 + admissibility) * h), g, h)

GridCell() = GridCell(typemax(Int), typemax(Int), typemax(Int))

"""
    find_path(pathfinder::AStar{D}, from::NTuple{D,Int}, to::NTuple{D,Int})
Using the specified [`AStar`](@ref), calculates and returns the shortest path from `from` to `to` using the A* algorithm.
Paths are returned as a [`Path{D}`](@ref). If a path does not exist between the given positions, this returns an empty
[`Path{D}`](@ref). This function usually does not need to be called explicitly, instead the use the provided
[`set_target!`](@ref) and [`move_agent!`](@ref) functions.
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
            nbor_cell = get(grid, nbor, GridCell())
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
    while get(parent, cur, nothing) !== nothing
        pushfirst!(agent_path, cur)
        cur = get(parent, cur, nothing)
    end
    return agent_path
end

@inline get_neighbors(cur, pathfinder::AStar{D,true}) where {D} =
    (mod1.(cur .+ β.I, pathfinder.grid_dims) for β in pathfinder.neighborhood)
@inline get_neighbors(cur, pathfinder::AStar{D,false}) where {D} =
    (cur .+ β.I for β in pathfinder.neighborhood)
@inline inbounds(n, pathfinder, closed) =
    all(1 .<= n .<= pathfinder.grid_dims) && pathfinder.walkable[n...] && n ∉ closed

"""
    set_target!(agent::A, target::NTuple{D,Int}, model::ABM{<:GridSpace,A,<:AStar{D}})
This calculates and stores the shortest path to move the agent from its current position to `target`
using [`find_path`](@ref).
"""
function set_target!(
    agent::A,
    target::Dims{D},
    model::ABM{<:GridSpace{D},A,<:AStar{D}},
) where {D,A<:AbstractAgent}
    model.pathfinder.agent_paths[agent.id] = find_path(model.pathfinder, agent.pos, target)
end

Base.isempty(id::Int, pathfinder::AStar) =
    get(pathfinder.agent_paths, id, nothing) === nothing ||
    isempty(pathfinder.agent_paths[id])

"""
    move_agent!(agent::A, model::ABM{<:GridSpace,A,<:AStar})
Moves the agent along the path to its target set by [`set_target!`](@ref). If the agent does
not have a precalculated path, or the path is empty, the agent does not move.
"""
function move_agent!(
    agent::A,
    model::ABM{<:GridSpace{D},A,<:AStar{D}},
) where {D,A<:AbstractAgent}
    isempty(agent.id, model.pathfinder) && return

    move_agent!(agent, first(model.pathfinder.agent_paths[agent.id]), model)
    popfirst!(model.pathfinder.agent_paths[agent.id])
end

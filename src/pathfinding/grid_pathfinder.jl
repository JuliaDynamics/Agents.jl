export CostMetric,
    DirectDistance,
    MaxDistance,
    HeightMap,
    AStar,
    delta_cost,
    find_path,
    set_target!,
    move_along_path!,
    is_stationary,
    heightmap,
    walkmap,
    Pathfinder

"""
    Path{D}
Alias of `MutableLinkedList{Dims{D}}`. Used to represent the path to be
taken by an agent in a `D` dimensional [`GridSpace`](@ref).
"""
const Path{D} = MutableLinkedList{Dims{D}}

struct DirectDistance{D} <: CostMetric{D}
    direction_costs::Vector{Int}
end

Base.show(io::IO, metric::DirectDistance) = print(io, "DirectDistance")

"""
    DirectDistance{D}([direction_costs::Vector{Int}]) <: CostMetric{D}
Distance is approximated as the shortest path between the two points, provided the
`walkable` property of [`AStar`](@ref) allows.
Optionally provide a `Vector{Int}` that represents the cost of going from a tile to the
neighboring tile on the `i` dimensional diagonal (default is `10√i`).

If `diagonal_neighbors=false` in [`Pathfinder`](@ref), neighbors in diagonal positions will be
excluded. Cost defaults to the first value of the provided vector.
"""
DirectDistance{D}() where {D} = DirectDistance{D}([floor(Int, 10.0 * √x) for x in 1:D])

"""
    MaxDistance{D}() <: CostMetric{D}
Distance between two tiles is approximated as the maximum of absolute
difference in coordinates between them.
"""
struct MaxDistance{D} <: CostMetric{D} end

Base.show(io::IO, metric::MaxDistance) = print(io, "MaxDistance")

struct HeightMap{D} <: CostMetric{D}
    base_metric::CostMetric{D}
    hmap::Array{Int,D}
end

Base.show(io::IO, metric::HeightMap) =
    print(io, "HeightMap with base: $(metric.base_metric)")

"""
    HeightMap(hmap::Array{Int,D} [, base_metric::Union{Type{<:CostMetric}, <:CostMetric}]) <: CostMetric{D}
Distance between two positions is the sum of the shortest distance between them and the
absolute difference in height. A heightmap of the same size as the corresponding
[`GridSpace{D}`](@ref) is required. Distance is calculated using [`DirectDistance`](@ref)
by default, and can be changed by specifying `base_metric`.
"""
HeightMap(hmap::Array{Int,D}) where {D} = HeightMap{D}(DirectDistance{D}(), hmap)

HeightMap(hmap::Array{Int,D}, base_metric::Union{Type{M},M}) where {D,M<:CostMetric} =
    HeightMap{D}(typeof(base_metric) <: CostMetric ? base_metric : base_metric{D}(), hmap)

struct AStar{D,P,M} <: AbstractPathfinder
    agent_paths::Dict{Int,Path{D}}
    grid_dims::Dims{D}
    neighborhood::Vector{CartesianIndex{D}}
    admissibility::Float64
    walkable::Array{Bool,D}
    cost_metric::CostMetric{D}

    function AStar{D,P,M}(
        agent_paths::Dict,
        grid_dims::Dims{D},
        neighborhood::Vector{CartesianIndex{D}},
        admissibility::Float64,
        walkable::Array{Bool,D},
        cost_metric::CostMetric{D},
    ) where {D,P,M}
        @assert admissibility >= 0 "Invalid value for admissibility: $admissibility ≱ 0"
        @assert typeof(cost_metric) != HeightMap{D} || size(cost_metric.hmap) == grid_dims "Heightmap dimensions must be same as provided space"
        new(agent_paths, grid_dims, neighborhood, admissibility, walkable, cost_metric)
    end
end

"""
    AStar(space::GridSpace; kwargs...)
Provides pathfinding capabilities and stores agent paths. Dimensionality and periodicity
properties are taken from `space`.

`diagonal_neighbors = true` specifies if movement can be to diagonal neighbors of a
tile, or only orthogonal neighbors.

`admissibility = 0.0` specifies how much a path can deviate from optimal, in favour of
faster pathfinding. Admissibility (`ε`) of `0.0` will always find the optimal path.
Larger values of `ε` will explore fewer nodes, returning a path length with at most
`(1+ε)` times the optimal path length.

`walkable = fill(true, size(space))` is used to specify (un)walkable positions of the
space. All positions are assumed to be walkable by default.

`cost_metric = DirectDistance` specifies the metric used to approximate the distance
between any two walkable points on the grid. See [`CostMetric`](@ref).

Example usage in [Maze Solver](@ref) and [Mountain Runners](@ref).
"""
function AStar(
    dims::Dims{D};
    periodic::Bool = false,
    diagonal_neighbors::Bool = true,
    admissibility::Float64 = 0.0,
    walkable::Array{Bool,D} = fill(true, dims),
    cost_metric::Union{Type{M},M} = DirectDistance,
) where {D,M<:CostMetric}
    neighborhood = diagonal_neighbors ? moore_neighborhood(D) : vonneumann_neighborhood(D)
    if typeof(cost_metric) <: CostMetric
        metric = cost_metric
    else
        metric = cost_metric{D}()
    end
    return AStar{D,periodic,moore_neighbors}(
        Dict{Int,Path{D}}(),
        dims,
        neighborhood,
        admissibility,
        walkable,
        metric,
    )
end

function AStar(dims::Dims{D}, periodic::Bool, pathfinder::Pathfinder) where {D}
    walkable = pathfinder.walkable === nothing ? fill(true, dims) : pathfinder.walkable

    if typeof(pathfinder.cost_metric) <: CostMetric
        metric = pathfinder.cost_metric
    else
        metric = pathfinder.cost_metric{D}()
    end
    neighborhood =
        pathfinder.diagonal_neighbors ? moore_neighborhood(D) : vonneumann_neighborhood(D)
    return AStar{D,periodic,pathfinder.diagonal_neighbors}(
        Dict{Int,Path{D}}(),
        dims,
        neighborhood,
        pathfinder.admissibility,
        walkable,
        metric,
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
    periodic = P ? "periodic, " : ""
    moore = M ? "moore, " : ""
    s = "A* in $(D) dimensions. $(periodic)$(moore)ϵ=$(pathfinder.admissibility), metric=$(pathfinder.cost_metric)"
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
Calculate the shortest path from `from` to `to` using the A* algorithm.
If a path does not exist between the given positions, an empty linked list is returned.

This function usually does not need to be called explicitly, instead
the use the provided [`set_target!`](@ref) and [`move_along_path!`](@ref) functions.
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

"""
    set_target!(agent::A, target::NTuple{D,Int}, model::ABM{<:GridSpace{D,P,<:AStar{D}},A})
This calculates and stores the shortest path to move the agent from its current position to `target`
using [`find_path`](@ref).
"""
function set_target!(
    agent::A,
    target::Dims{D},
    model::ABM{<:GridSpace{D,P,<:AStar{D}},A},
) where {D,P,A<:AbstractAgent}
    model.space.pathfinder.agent_paths[agent.id] =
        find_path(model.space.pathfinder, agent.pos, target)
end

function set_best_target!(
    agent::A,
    targets::Vector{Dims{D}},
    model::ABM{<:GridSpace{D,P,<:AStar{D}},A},
) where {D,P,A<:AbstractAgent}
    best_path = Path()
    for target in targets
        path = find_path(model.space.pathfinder, agent.pos, target)
        if isempty(best_path) || length(path) < length(best_path)
            best_path = path
        end
    end

    model.space.pathfinder.agent_paths[agent.id] = best_path
end

"""
    is_stationary(agent, model::ABM{<:GridSpace{D,P,<:AStar{D}},A})
Return `true` if agent has reached it's target destination, or no path has been set for it.
"""
is_stationary(
    agent::A,
    model::ABM{<:GridSpace{D,P,<:AStar{D}},A},
) where {D,P,A<:AbstractAgent} = isempty(agent.id, model.space.pathfinder)

Base.isempty(id::Int, pathfinder::AStar) =
    !haskey(pathfinder.agent_paths, id) || isempty(pathfinder.agent_paths[id])

"""
    heightmap(model::ABM{<:GridSpace{D,P,<:AStar{D}}})
Return the heightmap of the pathfinder if the [`HeightMap`](@ref) metric is in use,
`nothing` otherwise.
"""
function heightmap(model::ABM{<:GridSpace{D,P,<:AStar{D}}}) where {D,P}
    if model.space.pathfinder.cost_metric isa HeightMap
        return model.space.pathfinder.cost_metric.hmap
    else
        return nothing
    end
end

"""
    walkmap(model::ABM{<:GridSpace{D,P,<:AStar{D}}})
Return the walkable map of the pathfinder
"""
walkmap(model::ABM{<:GridSpace{D,P,<:AStar{D}}}) where {D,P} =
    model.space.pathfinder.walkable

"""
    move_along_path!(agent::A, model::ABM{<:GridSpace{D,P,<:AStar{D}},A})
Moves the agent along the path to its target set by [`set_target!`](@ref). If the agent does
not have a precalculated path, or the path is empty, the agent does not move.
"""
function move_along_path!(
    agent::A,
    model::ABM{<:GridSpace{D,P,<:AStar{D}},A},
) where {D,P,A<:AbstractAgent}
    isempty(agent.id, model.space.pathfinder) && return

    move_agent!(agent, first(model.space.pathfinder.agent_paths[agent.id]), model)
    popfirst!(model.space.pathfinder.agent_paths[agent.id])
end

function kill_agent!(
    agent::A,
    model::ABM{<:GridSpace{D,P,<:AStar{D}},A},
) where {D,P,A<:AbstractAgent}
    delete!(model.space.pathfinder.agent_paths, agent.id)
    delete!(model.agents, agent.id)
    remove_agent_from_space!(agent, model)
end

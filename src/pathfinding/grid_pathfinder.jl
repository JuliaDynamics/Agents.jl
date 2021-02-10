export CostMetric, DefaultCostMetric, HeightMapMetric, Pathfinder, Path, delta_cost, find_path, set_target!, move_agent!

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
base type is used as the `cost_metric` for the [`Pathfinder`](@ref). To define a custom metric,
define a struct with this as its base type and a corresponding method for [`delta_cost`](@ref).
"""
abstract type CostMetric{D} end

struct DefaultCostMetric{D} <: CostMetric{D}
    direction_costs::Array{Int,1}
end

"""
    DefaultCostMetric{D}(direction_costs::Array{Int,1}=[Int(floor(10.0√x)) for x in 1:D])
The default metric [`CostMetric{D}`](@ref). Distance is approximated as the shortest path between
the two points, ignoring any unwalkable areas. `direction_costs` is an `Array{Int,1}` where 
`direction_costs[i]` represents the cost of traveling the `i` dimensional diagonal. The default value
is `10√i` for the `i` dimensional diagonal, rounded down to the nearest integer.
"""
DefaultCostMetric{D}() where {D} = DefaultCostMetric{D}([Int(floor(10.0√x)) for x in 1:D])

struct HeightMapMetric{D} <: CostMetric{D}
    default_metric::DefaultCostMetric{D}
    hmap::Array{Int,D}
end

"""
    HeightMapMetric(hmap::Array{Int,D})
An alternative [`CostMetric{D}`](@ref). This allows for a `D` dimensional heightmap to be provided as a
`D` dimensional integer array, of the same size as the corresponding [`GridSpace{D}`](@ref). This metric
approximates the distance between two positions as the sum of the shortest path between them (as calculated
by [`DefaultCostMetric{D}`](@ref)) and the absolute difference in heights between the two positions.
"""
HeightMapMetric(hmap::Array{Int,D}) where {D} = HeightMapMetric{D}(DefaultCostMetric{D}(), hmap)
"""
    HeightMapMetric(direction_costs::Array{Int,1}, hmap::Array{Int,D})
An alternative constructor for [`HeightMapMetric`](@ref) that also allows setting the `direction_costs`
parameter of the underlying [`DefaultCostMetric{D}`](@ref).
"""
HeightMapMetric(
    direction_costs::Array{Int,1},
    hmap::Array{Int,D}
) where {D} = HeightMapMetric{D}(DefaultCostMetric{D}(direction_costs), hmap)

mutable struct Pathfinder{D,P}
    agent_paths::Dict{Int,Path{D}}
    grid_dims::Dims{D}
    walkable::Array{Bool,D}
    cost_metric::CostMetric{D}
end

"""
    Pathfinder(space::GridSpace{D,P}; kwargs...)
Stores path data of agents, and relevant pathfinding grid data. The dimensions are taken to be those of the space.

The keyword argument `walkable::Array{Bool,D}=fill(true, size(space.s))` is used to specify (un)walkable positions of
the space. Unwalkable positions are never part of any paths. By default, all positions are assumed to be walkable

The keyword argument `cost_metric::CostMetric{D}=DefaultCostMetric{D}()` specifies the metric used to approximate
the distance between any two walkable points on the grid. This must be a struct with base type [`CostMetric{D}`](@ref)
and having a corresponding method for [`delta_cost`](@ref). The default value is [`DefaultCostMetric{D}`](@ref).
"""
Pathfinder(
    space::GridSpace{D,P};
    walkable::Array{Bool,D}=fill(true, size(space.s)),
    cost_metric::CostMetric{D}=DefaultCostMetric{D}()
) where {D,P} = Pathfinder{D,P}(Dict{Int,Path{D}}(), size(space.s), walkable, cost_metric)

function delta_cost(
    pathfinder::Pathfinder{D,periodic},
    metric::DefaultCostMetric{D},
    from::Dims{D},
    to::Dims{D}
) where {D,periodic}    
    delta = collect(
        periodic ? min.(abs.(to .- from), pathfinder.grid_dims .- abs.(to .- from)) :
        abs.(to .- from),
    )
    sort!(delta)
    carry = 0
    hdist = 0
    for i = D:-1:1
        hdist += metric.direction_costs[i] * (delta[D + 1 - i] - carry)
        carry = delta[D + 1 - i]
    end
    return hdist
end

delta_cost(
    pathfinder::Pathfinder{D,periodic},
    metric::HeightMapMetric{D},
    from::Dims{D},
    to::Dims{D}
) where {D,periodic} = delta_cost(pathfinder, metric.default_metric, from, to) + abs(metric.hmap[from...] - metric.hmap[to...])

"""
    delta_cost(pathfinder::Pathfinder{D}, from::NTuple{D, Int}, to::NTuple{D, Int})
Calculates and returns an approximation for the cost of travelling from `from` to `to`. This calls the corresponding
`delta_cost(pathfinder, pathfinder.cost_metric, from, to)` function. In the case of a custom metric, define a method for
the latter function.
"""
delta_cost(pathfinder::Pathfinder{D}, from::Dims{D}, to::Dims{D}) where {D} = delta_cost(pathfinder, pathfinder.cost_metric, from, to)

struct GridCell
    f::Int
    g::Int
    h::Int
end

GridCell(g::Int, h::Int) = GridCell(g + h, g, h)

"""
    find_path(pathfinder::Pathfinder{D,periodic}, from::NTuple{D, Int}, to::NTuple{D,Int})
Using the specified [`Pathfinder`](@ref), calculates and returns the shortest path from `from` to `to` using the A* algorithm.
Paths are returned as a [`Path{D}`](@ref). If a path does not exist between the given positions, this returns an empty
[`Path{D}`](@ref). This function usually does not need to be called explicitly, instead the use the provided [`set_target!`](@ref)
and [`move_agent!`](@ref) functions.
"""
function find_path(
    pathfinder::Pathfinder{D,periodic},
    from::Dims{D},
    to::Dims{D},
) where {D,periodic}
    grid = DefaultDict{Dims{D},GridCell}(GridCell(typemax(Int), typemax(Int), typemax(Int)))
    parent = DefaultDict{Dims{D},Union{Nothing,Dims{D}}}(nothing)

    neighbor_offsets = [
        Tuple(a)
        for a in Iterators.product([(-1):1 for φ = 1:D]...) if a != Tuple(zeros(Int, D))
    ]
    open_list = BinaryMinHeap{Tuple{Int,Dims{D}}}()
    closed_list = Set{Dims{D}}()

    grid[from] = GridCell(0, delta_cost(pathfinder, from, to))
    push!(open_list, (grid[from].f, from))

    while !isempty(open_list)
        _, cur = pop!(open_list)
        push!(closed_list, cur)
        cur == to && break

        for offset in neighbor_offsets
            nbor = cur .+ offset
            periodic &&
                (nbor = (nbor .- 1 .+ pathfinder.grid_dims) .% pathfinder.grid_dims .+ 1)
            all(1 .<= nbor .<= pathfinder.grid_dims) || continue
            pathfinder.walkable[nbor...] || continue
            nbor in closed_list && continue
            new_g_cost = grid[cur].g + delta_cost(pathfinder, cur, nbor)
            if new_g_cost < grid[nbor].g
                parent[nbor] = cur
                grid[nbor] = GridCell(new_g_cost, delta_cost(pathfinder, nbor, to))
                # open list will contain duplicates. Can this be avoided?
                push!(open_list, (grid[nbor].f, nbor))
            end
        end
    end

    agent_path = Path{D}()
    cur = to
    while parent[cur] !== nothing
        pushfirst!(agent_path, cur)
        cur = parent[cur]
    end
    return agent_path
end

"""
    set_target(agent, pathfinder::Pathfinder{D}, target::NTuple{D,Int})
This calculates and stores the shortest path to move the agent from its current position to `target`
using [`find_path`](@ref).
"""
function set_target!(agent, pathfinder::Pathfinder{D}, target::Dims{D}) where {D}
    pathfinder.agent_paths[agent.id] = find_path(pathfinder, agent.pos, target)
end

"""
    move_agent!(agent, model::ABM{<:GridSpace{D}}, pathfinder::Pathfinder{D})
Moves the agent along the path to its target set by [`set_target!`](@ref). If the agent does
not have a precalculated path, or the path is empty, nothing happens.
"""
function move_agent!(agent, model::ABM{<:GridSpace{D}}, pathfinder::Pathfinder{D}) where {D}
    get(pathfinder.agent_paths, agent.id, nil()) == nil() && return

    move_agent!(agent, first(pathfinder.agent_paths[agent.id]), model)
    popfirst!(pathfinder.agent_paths[agent.id])
end

const Path{D} = LinkedList{Dims{D}}
Path() = nil()

abstract type CostMetric{D,P} end

struct DefaultCostMetric{D,P} <: CostMetric{D,P}
    direction_costs::Array{Int,1}
end

DefaultCostMetric{D,P}() where {D,P} = DefaultCostMetric{D,P}([Int(floor(10.0 * sqrt(x))) for x = 1:D])

struct HeightMapMetric{D,P} <: CostMetric{D,P}
    default_metric::DefaultCostMetric{D,P}
    hmap::Array{Int, D}
end

HeightMapMetric{D,P}(hmap::Array{Int,D}) where {D,P} = HeightMapMetric{D,P}(DefaultCostMetric{D,P}(), hmap)

function delta_cost(pathfinder::Pathfinder{D,periodic}, metric::DefaultCostMetric{D,periodic}, from::Dims{D}, to::Dims{D}) where {D,periodic}
    delta = collect(
        periodic ? min.(abs.(to .- from), pathfinder.grid_dims .- abs.(to .- from)) :
        abs.(to .- from),
    )
    sort!(delta)
    carry = 0
    hdist = 0
    for i = D:-1:1
        hdist += metric.direction_costs[i] * (delta[D+1-i] - carry)
        carry = delta[D+1-i]
    end
    return hdist
end

function delta_cost(pathfinder::Pathfinder{D,periodic}, metric::HeightMapMetric{D,periodic}, from::Dims{D}, to::Dims{D}) where {D,periodic}
    return delta_cost(pathfinder, metric.default_metric, from, to)^2 + (metric.hmap[from...]-metric.hmap[to...])^2
end

mutable struct Pathfinder{D,P}
    agent_paths::Dict{Int,Path{D}}
    grid_dims::Dims{D}
    walkable::Array{Bool,D}
    cost_metric::CostMetric{D,P}
end

Pathfinder(
    model::ABM{<:GridSpace{D,P}};
    walkable::Array{Bool,D} = fill(true, size(model.space.s)),
    cost_metric::CostMetric{D,P} = DefaultCostMetric{D,P}()
) where {D,P} = Pathinder{D,P}(Dict{Int,Path{D}}(), size(model.space.s), walkable, cost_metric)

delta_cost(pathfinder::Pathfinder{D}, from::Dims{D}, to::Dims{D}) where {D} = delta_cost(pathfinder, pathfinder.cost_metric, from, to)

struct GridCell
    f::Int
    g::Int
    h::Int
end

GridCell(g::Int, h::Int) = GridCell(g + h, g, h)

function find_path(
    pathfinder::Pathfinder{D,periodic},
    from::Dims{D},
    to::Dims{D},
) where {D,periodic}
    grid = DefaultDict{Dims{D},GridCell}(GridCell(typemax(Int), typemax(Int), typemax(Int)))
    parent = DefaultDict{Dims{D},Union{Nothing,Dims{D}}}(nothing)

    neighbor_offsets = [
        Tuple(a)
        for
        a in Iterators.product([(-1):1 for φ = 1:D]...) if a != Tuple(zeros(Int, D))
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

    agent_path = Path()
    cur = to
    while parent[cur] != nothing
        agent_path = cons(cur, agent_path)
        cur = parent[cur]
    end
    return agent_path
end

function set_target(agent, pathfinder::Pathfinder{D}, target::Dims{D}) where {D}
    pathfinder.agent_paths[agent.id] = find_path(pathfinder, agent.pos, target)
end

function move_agent!(agent, model::ABM{<:GridSpace{D}}, pathfinder::Pathfinder{D}) where {D}
    get(pathfinder.agent_paths, agent.id, nil()) == nil() && return

    move_agent!(agent, first(pathfinder.agent_paths[agent.id]), model)
    popfirst!(pathfinder.agent_paths[agent.id])
end

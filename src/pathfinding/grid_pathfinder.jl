const Path{D} = LinkedList{Dims{D}}
Path() = nil()

mutable struct Pathfinder{D}
    agent_paths::Dict{Int, Path{D}}
    grid_dims::Dims{D}
    walkable::Array{Bool, D}
end

struct GridCell
    f::Int
    g::Int
    h::Int
end

GridCell(g::Int, h::Int) = GridCell(g+h, g, h)
sumabs(v) = sum(abs.(v))

function find_path(
    pathfinder::Pathfinder{D},
    from::Dims{D},
    to::Dims{D},
) where{D}
    # use a DefaultDict instead?
    grid = fill(GridCell(typemax(Int), typemax(Int), typemax(Int)), pathfinder.grid_dims...)
    parent = Array{Union{Nothing, Dims{D}}, D}(nothing, pathfinder.grid_dims...)
    border_dists = [Int(floor(10. * sqrt(x))) for x in 1:D]
    function dist_cost(delta)
        delta = collect(abs.(delta))
        sort!(delta)
        carry = 0
        hdist = 0
        for i in D:-1:1
            hdist += border_dists[i] * (delta[D+1-i] - carry)
            carry = delta[D+1-i]
        end
        return hdist
    end

    neighbor_offsets = [Tuple(a) for a in Iterators.product([(-1):1 for φ in 1:D]...) if a != zeros(D)]
    open_list = BinaryMinHeap{Tuple{Int, Dims{D}}}()
    closed_list = Set{Dims{D}}()

    grid[from...] = GridCell(0, dist_cost(to .- from))
    push!(open_list, (grid[from...].f, from))

    while !isempty(open_list)
        _, cur = pop!(open_list)

        push!(closed_list, cur)
        cur == to && break

        for offset in neighbor_offsets
            nbor = cur.+offset
            all(1 .<= nbor .<= pathfinder.grid_dims) || continue
            pathfinder.walkable[nbor...] || continue
            nbor in closed_list && continue

            new_g_cost = grid[cur...].g + dist_cost(offset)
            if new_g_cost < grid[nbor...].g
                parent[nbor...] = cur
                grid[nbor...] = GridCell(new_g_cost, dist_cost(to.-nbor))
                # open list will contain duplicates. Can this be avoided?
                push!(open_list, (grid[nbor...].f, nbor))
            end
        end
    end

    agent_path = Path()
    cur = to
    while parent[cur...] != nothing
        agent_path = cons(cur, agent_path)
        cur = parent[cur...]
    end
    return agent_path
end

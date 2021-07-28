to_discrete_position(pos, pathfinder) =
    floor.(Int, pos ./ pathfinder.dims .* size(pathfinder.walkable)) .+ 1
to_continuous_position(pos, pathfinder) =
    pos ./ size(pathfinder.walkable) .* pathfinder.dims .-
    pathfinder.dims ./ size(pathfinder.walkable) ./ 2.
sqr_distance(from, to, pathfinder) =
    sum(min.(abs.(from .- to), pathfinder.dims .- abs.(from .- to)) .^ 2)
"""
    find_continuous_path(pathfinder, from, to, model)
Functions like `find_path``, but uses the output of `find_path` and converts it to the coordinate
space used by `model.space` (which is continuous). Also performs checks on the last two waypoints
in the discrete path to ensure continuous path is optimal.
"""
function find_continuous_path(
    pathfinder::AStar{D},
    from::NTuple{D,Float64},
    to::NTuple{D,Float64},
) where {D}
    # used to offset positions, so edge cases get handled properly (i.e. (0., 0.) maps to grid
    # cell (1, 1))
    discrete_from = to_discrete_position(from, pathfinder)
    discrete_to = to_discrete_position(to, pathfinder)
    discrete_path = find_path(pathfinder, discrete_from, discrete_to)
    isnothing(discrete_path) && return
    isempty(discrete_path) && return Path{D,Float64}()
    cts_path = Path{D,Float64}()
    for pos in discrete_path
        push!(cts_path, to_continuous_position(pos, pathfinder))
    end
    last_pos = last(cts_path)
    pop!(cts_path)
    second_last_pos = isempty(cts_path) ? from : last(cts_path)
    last_to_end = sqr_distance(last_pos, to, pathfinder)
    second_last_to_end = sqr_distance(second_last_pos, to, pathfinder)
    if last_to_end < second_last_to_end
        push!(cts_path, last_pos)
    end
    last_to_end ≈ 0. || push!(cts_path, to)
    return cts_path
end

"""
    Pathfinding.set_target!(agent, target::NTuple{D,Float64}, pathfinder::AStar{D}, model::ABM{<:ContinuousSpace{D}})
Calculate and store the shortest path to move the agent from its current position to
`target` (a continuous position e.g. `(1.2, 5.7)`) using the provided `pathfinder`.

For pathfinding in models with [`ContinuousSpace`](@ref).

Use this method in conjuction with [`move_along_route!`](@ref).
"""
function set_target!(
    agent::A,
    target::NTuple{D,Float64},
    pathfinder::AStar{D,P,M,Float64},
) where {A<:AbstractAgent,D,P,M}
    path = find_continuous_path(pathfinder, agent.pos, target)
    isnothing(path) && return
    pathfinder.agent_paths[agent.id] = path
end

"""
    Pathfinding.set_best_target!(agent, targets::Vector{NTuple{D,Float64}}, pathfinder::AStar{D}, model::ABM{<:ContinuousSpace{D}})
Calculate and store the best path to move the agent from its current position to
a chosen target position taken from `targets` for models using the provided `pathfinder`.

For pathfinding in models with [`ContinuousSpace`](@ref).

The `condition = :shortest` keyword retuns the path which is shortest
(allowing for the conditions of the pathfinder) out of the possible target
positions. Alternatively, the `:longest` path may also be requested.

Returns the position of the chosen target.
"""
function set_best_target!(
    agent::A,
    targets::Vector{NTuple{D,Float64}},
    pathfinder::AStar{D};
    condition::Symbol = :shortest,
) where {D,A<:AbstractAgent}
    @assert condition ∈ (:shortest, :longest)
    compare = condition == :shortest ? (a, b) -> a < b : (a, b) -> a > b
    best_path = Path{D,Float64}()
    best_target = nothing
    for target in targets
        path = find_continuous_path(pathfinder, agent.pos, target)
        isnothing(path) && continue
        if isempty(best_path) || compare(length(path), length(best_path))
            best_path = path
            best_target = target
        end
    end

    isnothing(best_target) && return
    pathfinder.agent_paths[agent.id] = best_path
    return best_target
end

"""
    move_along_route!(agent, model::ABM{<:ContinuousSpace{D}}, pathfinder::AStar{D}, speed, dt = 1.0)
Move `agent` for one step along the route toward its target set by
[`Pathfinding.set_target!`](@ref) at the given `speed` and timestep `dt`.

For pathfinding in models with [`ContinuousSpace`](@ref)

If the agent does not have a precalculated path or the path is empty, it remains stationary.
"""
function Agents.move_along_route!(
    agent::A,
    model::ABM{<:ContinuousSpace{D},A},
    pathfinder::AStar{D},
    speed::Float64,
    dt::Real = 1.0,
) where {D,A<:AbstractAgent}
    isempty(agent.id, pathfinder) && return
    from = agent.pos
    next_pos = agent.pos
    while true
        next_waypoint = first(pathfinder.agent_paths[agent.id])
        dir = get_direction(from, next_waypoint, model)
        dist_to_target = √sum(dir .^ 2)
        dir = dir ./ dist_to_target
        next_pos = from .+ dir .* speed .* dt

        # overshooting means we reached the waypoint
        dist_to_next = edistance(from, next_pos, model)
        if dist_to_next > dist_to_target
            # change from and dt so it appears we're coming from the waypoint just skipped, instead
            # of directly where the agent was. E.g:
            # agent.pos = (0, 0)
            # pathfinder.agent_paths[agent.id] = [(1, 0), (1, 1)]
            # speed = 1
            # dt = 1.2
            # without this, agent would end up at (0.85, 0.85) instead of (1, 0.2)
            from = next_waypoint
            dt -= dist_to_target / speed
            popfirst!(pathfinder.agent_paths[agent.id])
            # if the path is now empty, go directly to the end
            if isempty(agent.id, pathfinder)
                next_pos = next_waypoint
                break
            end
        else
            break
        end
    end

    move_agent!(agent, next_pos, model)
end

function random_walkable(model::ABM{<:ContinuousSpace{D}}, pathfinder::AStar{D}) where {D}
    discrete_pos = Tuple(rand(
        model.rng,
        filter(x -> pathfinder.walkable[x], CartesianIndices(pathfinder.walkable))
    ))
    half_cell_size = model.space.extent ./ size(pathfinder.walkable) ./ 2.
    return to_continuous_position(discrete_pos, pathfinder) .+
        Tuple(rand(model.rng, D) .- 0.5) .* half_cell_size
end

walkable_cells_in_radius(pos, r, pathfinder::AStar{D,false}) where {D} =
    Iterators.filter(
        x -> all(1 .<= x .<= size(pathfinder.walkable)) &&
            pathfinder.walkable[x...] &&
            sum(((x .- pos) ./ r) .^ 2) <= 1,
        Iterators.product([(pos[i]-r[i]):(pos[i]+r[i]) for i in 1:D]...)
    )

walkable_cells_in_radius(pos, r, pathfinder::AStar{D,true}) where {D} =
    Iterators.map(
        x -> mod1.(x, size(pathfinder.walkable)),
            Iterators.filter(
                x -> pathfinder.walkable[mod1.(x, size(pathfinder.walkable))...] && sum(((x .- pos) ./ r) .^ 2) <= 1,
                Iterators.product([(pos[i]-r[i]):(pos[i]+r[i]) for i in 1:D]...)
            )
    )

"""
    Pathfinding.random_walkable(pos, mode::ABM{<:ContinuousSpace{D}}, pathfinder::AStar{D}, r = 1.0)
Return a random position within radius `r` of `pos` which is walkable, as specified by `pathfinder`.
"""
function random_walkable(
    pos,
    model::ABM{<:ContinuousSpace{D}},
    pathfinder::AStar{D},
    r = 1.0,
) where {D}
    discrete_r = to_discrete_position(r, pathfinder) .- 1
    discrete_pos = to_discrete_position(pos, pathfinder)
    discrete_rand = rand(
        model.rng,
        collect(walkable_cells_in_radius(discrete_pos, discrete_r, pathfinder))
    )
    half_cell_size = model.space.extent ./ size(pathfinder.walkable) ./ 2.
    cts_rand = to_continuous_position(discrete_rand, pathfinder) .+
        Tuple(rand(model.rng, D) .- 0.5) .* half_cell_size
    dist = edistance(pos, cts_rand, model)
    dist > r && (cts_rand = mod1.(
        pos .+ get_direction(pos, cts_rand, model) ./ dist .* r,
        model.space.extent
    ))
    return cts_rand
end

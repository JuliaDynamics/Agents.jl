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
    model::ABM{<:ContinuousSpace{D}}
) where {D}
    # used to offset positions, so edge cases get handled properly (i.e. (0., 0.) maps to grid
    # cell (1, 1))
    half_cell_size = model.space.extent ./ pathfinder.grid_dims ./ 2.
    discrete_from = Tuple(Agents.get_spatial_index(from, pathfinder.walkable, model))
    discrete_to = Tuple(Agents.get_spatial_index(to, pathfinder.walkable, model))
    discrete_path = find_path(pathfinder, discrete_from, discrete_to)
    isnothing(discrete_path) && return
    isempty(discrete_path) && return Path{D,Float64}()
    cts_path = Path{D,Float64}()
    for pos in discrete_path
        push!(cts_path, pos ./ pathfinder.grid_dims .* model.space.extent .- half_cell_size)
    end
    last_pos = last(cts_path)
    pop!(cts_path)
    second_last_pos = isempty(cts_path) ? from : last(cts_path)
    last_to_end = edistance(last_pos, to, model)
    second_last_to_end = edistance(second_last_pos, to, model)
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
    pathfinder::AStar{D},
    model::ABM{<:ContinuousSpace{D},A},
) where {D,A<:AbstractAgent}
    path = find_continuous_path(pathfinder, agent.pos, target, model)
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
    pathfinder::AStar{D},
    model::ABM{<:ContinuousSpace{D}};
    condition::Symbol = :shortest,
) where {D,A<:AbstractAgent}
    @assert condition ∈ (:shortest, :longest)
    compare = condition == :shortest ? (a, b) -> a < b : (a, b) -> a > b
    best_path = Path{D,Float64}()
    best_target = nothing
    for target in targets
        path = find_continuous_path(pathfinder, agent.pos, target, model)
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
        norm_dir = √sum(dir .^ 2)
        dir = dir ./ norm_dir
        next_pos = from .+ dir .* speed .* dt

        # overshooting means we reached the waypoint
        dist_to_target = edistance(from, next_waypoint, model)
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
    discrete_pos = rand(
        model.rng,
        filter(x -> pathfinder.walkable(x), CartesianIndices(pathfinder.walkable))
    )
    half_cell_size = model.space.extent ./ pathfinder.grid_dims ./ 2.
    return discrete_pos ./ pathfinder.grid_dims .* model.space.extent .- half_cell_size .+
        Tuple(rand(model.rng, D) .- 0.5) .* half_cell_size
end

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
    discrete_r = r ./ model.space.extent .* pathfinder.grid_dims
    discrete_pos = Tuple(Agents.get_spatial_index(pos, pathfinder.walkable, model))
    discrete_rand = rand(
        model.rng,
        filter(
            x -> pathfinder.walkable(discrete_pos .+ x) && sum(x .^ 2) <= r*r,
            Iterators.product([-discrete_r:discrete_r for _ in 1:D]...)
        )
    )
    half_cell_size = model.space.extent ./ pathfinder.grid_dims ./ 2.
    cts_rand = discrete_rand ./ pathfinder.grid_dims .* model.space.extent .- half_cell_size .+
        Tuple(rand(model.rng, D) .- 0.5) .* half_cell_size
    sq_dist = sum(cts_rand .^ 2)
    sq_dist > r*r && (cts_rand = cts_rand ./ √sq_dist .* r)
    return cts_rand
end

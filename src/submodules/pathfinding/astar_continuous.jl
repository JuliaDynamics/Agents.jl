"""
    find_continuous_path(pathfinder, from, to, model)
Functions like find_path, but uses the output of find_path and converts it to the coordinate
space used by model.space (which is continuous). Also performs checks on the last two waypoints
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
    discrete_from = floor.(Int, from ./ model.space.extent .* pathfinder.grid_dims) .+ 1
    discrete_to = floor.(Int, to ./ model.space.extent .* pathfinder.grid_dims) .+ 1
    discrete_path = find_path(pathfinder, discrete_from, discrete_to)
    isempty(discrete_path) && return
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
    Pathfinding.set_target!(agent, target::NTuple{D,Int}, pathfinder)
Calculate and store the shortest path to move the agent from its current position to
`target` (a grid position e.g. `(1, 5)`) for using the provided `pathfinder`.

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
    Pathfinding.set_best_target!(agent, targets::Vector{NTuple{D,Int}}, pathfinder)

Calculate and store the best path to move the agent from its current position to
a chosen target position taken from `targets` for models using [`Pathfinding`](@ref).

The `condition = :shortest` keyword retuns the shortest path which is shortest
(allowing for the conditions of the models pathfinder) out of the possible target
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

    pathfinder.agent_paths[agent.id] = best_path
    return best_target
end

"""
    get_direction(from, to, space)
Returns the direction vector from `from` to `to` taking into account periodicity of the space
(for continuous space)
"""
# TODO: Dispatch on AStar's periodicity, since it's _technically_ possible for it to be different
# from the space
function get_direction(from::NTuple{D,Float64}, to::NTuple{D,Float64}, space::ContinuousSpace{D,true}) where {D}
    all_dirs = [to .+ space.extent .* (i, j) .- from for i in -1:1, j in -1:1]
    return all_dirs[argmin(map(x -> sum(x .^ 2), all_dirs))]
end

function get_direction(from::NTuple{D,Float64}, to::NTuple{D,Float64}, ::ContinuousSpace{D,false}) where {D}
    return to .- from
end

"""
    move_along_route!(agent, model, pathfinder)
Move `agent` for one step along the route toward its target set by [`Pathfinding.set_target!`](@ref)
for agents on a [`GridSpace`](@ref) using a [`Pathfinding.AStar`](@ref).
If the agent does not have a precalculated path or the path is empty, it remains stationary.
"""
function Agents.move_along_route!(
    agent::A,
    speed::Float64,
    model::ABM{<:ContinuousSpace{D},A},
    pathfinder::AStar{D},
    dt::Real = 1.0,
) where {D,A<:AbstractAgent}
    isempty(agent.id, pathfinder) && return
    from = agent.pos
    next_pos = agent.pos
    while true
        next_waypoint = first(pathfinder.agent_paths[agent.id])
        dir = get_direction(from, next_waypoint, model.space)
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

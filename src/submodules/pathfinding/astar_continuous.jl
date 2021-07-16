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
    discrete_from = floor.(Int, from ./ model.space.extent .* pathfinder.grid_dims)
    discrete_to = floor.(Int, to ./ model.space.extent .* pathfinder.grid_dims)
    discrete_path = find_path(pathfinder, discrete_from, discrete_to)
    cts_path = Path{D,Float64}()
    for pos in discrete_path
        push!(cts_path, pos ./ pathfinder.grid_dims .* model.space.extent)
    end
    last_pos = last(cts_path)
    pop!(cts_path)
    second_last_pos = last(cts_path)
    if edistance(last_pos, to, model) < edistance(second_last_pos, to, model)
        push!(cts_path, last_pos)
    end
    push!(cts_path, to)
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
    pathfinder.agent_paths[agent.id] = find_continuous_path(pathfinder, agent.pos, target, model)
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
    targets::Vector{Dims{D}},
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
        if isempty(best_path) || compare(length(path), length(best_path))
            best_path = path
            best_target = target
        end
    end

    pathfinder.agent_paths[agent.id] = best_path
    return best_target
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
    pathfinder::AStar{D,false},
    dt::Real = 1.0,
) where {D,A<:AbstractAgent}
    isempty(agent.id, pathfinder) && return
    next_pos = agent.pos
    while true
        next_waypoint = first(pathfinder.agent_paths[agent.id])
        dir = next_waypoint .- agent.pos
        norm_dir = √sum(dir .^ 2)
        dir = dir ./ norm_dir
        next_pos = agent.pos .+ dir .* speed .* dt

        # overshooting means we reached the waypoint
        if edistance(agent.pos, next_pos, model) > edistance(agent.pos, next_waypoint, model)
            pop!(pathfinder.agent_paths[agent.id])
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


function Agents.move_along_route!(
    agent::A,
    speed::Float64,
    model::ABM{<:ContinuousSpace{D},A},
    pathfinder::AStar{D,true},
    dt::Real = 1.0,
) where {D,A<:AbstractAgent}
    isempty(agent.id, pathfinder) && return
    next_pos = agent.pos
    space_size = model.space.extent
    while true
        next_waypoint = first(pathfinder.agent_paths[agent.id])
        all_dirs = [next_waypoint .+ space_size .* (i, j) .- agent.pos for i in -1:1, j in -1:1]
        dir = all_dirs[argmin(filter(x -> sum(x .^ 2), all_dirs))]

        norm_dir = √sum(dir .^ 2)
        dir = dir ./ norm_dir
        next_pos = mod.(agent.pos .+ dir .* speed .* dt, space_size)

        # overshooting means we reached the waypoint
        if edistance(agent.pos, next_pos, model) > edistance(agent.pos, next_waypoint, model)
            pop!(pathfinder.agent_paths[agent.id])
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

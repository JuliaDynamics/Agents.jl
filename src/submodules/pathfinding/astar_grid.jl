"""
    plan_route!(agent, dest, pathfinder::AStar{D})
Calculate and store the shortest path to move the agent from its current position to
`dest` (a position e.g. `(1, 5)` or `(1.3, 5.2)`) using the provided `pathfinder`.

Use this method in conjunction with [`move_along_route!`](@ref).
"""
function Agents.plan_route!(
    agent::A,
    dest::Dims{D},
    pathfinder::AStar{D},
) where {D,A<:AbstractAgent}
    path = find_path(pathfinder, agent.pos, dest)
    isnothing(path) && return
    pathfinder.agent_paths[agent.id] = path
end

"""
    plan_best_route!(agent, dests, pathfinder::AStar{D}; kwargs...)
Calculate, store, and return the best path to move the agent from its current position to
a chosen destination taken from `dests` using `pathfinder`.

The `condition = :shortest` keyword returns the shortest path which is shortest out of the
possible destinations. Alternatively, the `:longest` path may also be requested.

Return the position of the chosen destination. Return `nothing` if none of the supplied
destinations are reachable.
"""
function Agents.plan_best_route!(
    agent::A,
    dests,
    pathfinder::AStar{D,P,M,Int64};
    condition::Symbol = :shortest,
) where {A<:AbstractAgent,D,P,M}
    @assert condition ∈ (:shortest, :longest)
    compare = condition == :shortest ? (a, b) -> a < b : (a, b) -> a > b
    best_path = Path{D,Int64}()
    best_target = nothing
    for target in dests
        path = find_path(pathfinder, agent.pos, target)
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
    move_along_route!(agent, model::ABM{<:GridSpace{D}}, pathfinder::AStar{D})
Move `agent` for one step along the route toward its target set by [`plan_route!`](@ref)

For pathfinding in models with [`GridSpace`](@ref).

If the agent does not have a precalculated path or the path is empty, it remains stationary.
"""
function Agents.move_along_route!(
    agent::A,
    model::ABM{<:GridSpace{D},A},
    pathfinder::AStar{D}
) where {D,A<:AbstractAgent}
    isempty(agent.id, pathfinder) && return

    move_agent!(agent, first(pathfinder.agent_paths[agent.id]), model)
    popfirst!(pathfinder.agent_paths[agent.id])
end

"""
    Pathfinding.nearby_walkable(position, model::ABM{<:GridSpace{D}}, pathfinder::AStar{D}, r = 1)
Return an iterator over all [`nearby_positions`](@ref) within "radius" `r` of the given
`position` (excluding `position`), which are walkable as specified by the given `pathfinder`.
"""
nearby_walkable(position, model::ABM{<:GridSpace{D}}, pathfinder::AStar{D}, r = 1) where {D} =
    Iterators.filter(x -> pathfinder.walkmap[x...] == 1, nearby_positions(position, model, r))


"""
    Pathfinding.random_walkable(model, pathfinder::AStar{D})
Return a random position in the given `model` that is walkable as specified by the given
`pathfinder`.
"""
function random_walkable(model::ABM{<:GridSpace{D}}, pathfinder::AStar{D}) where {D}
    return Tuple(rand(model.rng,
        filter(x -> pathfinder.walkmap[x], CartesianIndices(model.space.stored_ids))
    ))
end

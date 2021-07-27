"""
    Pathfinding.set_target!(agent, target::NTuple{D,Int}, pathfinder::AStar{D})
Calculate and store the shortest path to move the agent from its current position to
`target` (a grid position e.g. `(1, 5)`) for using the provided `pathfinder`.

Use this method in conjuction with [`move_along_route!`](@ref).
"""
function set_target!(
    agent::A,
    target::Dims{D},
    pathfinder::AStar{D},
) where {D,A<:AbstractAgent}
    path = find_path(pathfinder, agent.pos, target)
    isnothing(path) && return
    pathfinder.agent_paths[agent.id] = path
end

"""
    Pathfinding.set_best_target!(agent, targets::Vector{NTuple{D,Int}}, pathfinder::AStar{D})
Calculate and store the best path to move the agent from its current position to
a chosen target position taken from `targets` using `pathfinder`.

The `condition = :shortest` keyword retuns the shortest path which is shortest out of the
possible target positions. Alternatively, the `:longest` path may also be requested.

Returns the position of the chosen target, or `nothing` if none of the supplied targets are
reachable.
"""
function set_best_target!(
    agent::A,
    targets::Vector{Dims{D}},
    pathfinder::AStar{D};
    condition::Symbol = :shortest,
) where {D,A<:AbstractAgent}
    @assert condition ∈ (:shortest, :longest)
    compare = condition == :shortest ? (a, b) -> a < b : (a, b) -> a > b
    best_path = Path{D,Int64}()
    best_target = nothing
    for target in targets
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
Move `agent` for one step along the route toward its target set by [`Pathfinding.set_target!`](@ref)

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
    nearby_walkable(position, model::ABM{<:GridSpace{D}}, pathfinder::AStar{D}, r = 1)
Return an iterator over all [`nearby_positions`](@ref) within "radius" `r` of the given
`position` (excluding `position`), which are walkable as specified by the given `pathfinder`.
"""
nearby_walkable(position, model::ABM{<:GridSpace{D}}, pathfinder::AStar{D}, r = 1) where {D} =
    Iterators.filter(x -> pathfinder.walkable[x...] == 1, nearby_positions(position, model, r))


"""
    random_walkable(model, pathfinder::AStar{D})
Return a random position in the given `model` that is walkable as specified by the given
`pathfinder`.
"""
random_walkable(model::ABM{<:GridSpace{D}}, pathfinder::AStar{D}) where {D} =
    Tuple(rand(model.rng, filter(x -> pathfinder.walkable[x], CartesianIndices(model.space.s))))

"""
    Pathfinding.set_target!(agent, target::NTuple{D,Int}, pathfinder)
Calculate and store the shortest path to move the agent from its current position to
`target` (a grid position e.g. `(1, 5)`) for using the provided `pathfinder`.

Use this method in conjuction with [`move_along_route!`](@ref).
"""
function set_target!(
    agent::A,
    target::Dims{D},
    pathfinder::AStar{D},
) where {D,A<:AbstractAgent}
    pathfinder.agent_paths[agent.id] =
        find_path(pathfinder, agent.pos, target)
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
    pathfinder::AStar{D};
    condition::Symbol = :shortest,
) where {D,A<:AbstractAgent}
    @assert condition ∈ (:shortest, :longest)
    compare = condition == :shortest ? (a, b) -> a < b : (a, b) -> a > b
    best_path = Path{D}()
    best_target = nothing
    for target in targets
        path = find_path(pathfinder, agent.pos, target)
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
    model::ABM{<:GridSpace{D},A},
    pathfinder::AStar{D}
) where {D,A<:AbstractAgent}
    isempty(agent.id, pathfinder) && return

    move_agent!(agent, first(pathfinder.agent_paths[agent.id]), model)
    popfirst!(pathfinder.agent_paths[agent.id])
end
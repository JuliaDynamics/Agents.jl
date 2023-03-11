#=
This file establishes the agent-space interaction API.
All space types should implement this API (and obviously be subtypes of `AbstractSpace`)
Some functions DO NOT need to be implemented for every space, they are space agnostic.
These functions have complete source code here, while the functions that DO need to
be implemented for every space have only documentation strings here and an
error message.

In short: IMPLEMENT ALL FUNCTIONS IN SECTION "IMPLEMENT", WITH SAME ARGUMENTS!

In addition to the required functions, a minimal `AbstractAgent` struct with REQUIRED
fields should be supplied. See the top of src/core/agents.jl for examples.
=#
export move_agent!,
    add_agent!,
    add_agent_pos!,
    remove_agent!,
    remove_all!,
    random_position,
    nearby_positions,
    nearby_ids,
    nearby_agents,
    random_nearby_id,
    random_nearby_agent,
    random_nearby_position,
    plan_route!,
    plan_best_route!,
    move_along_route!,
    is_stationary

#######################################################################################
# %% IMPLEMENT
#######################################################################################
"""
    random_position(model) → pos
Return a random position in the model's space (always with appropriate Type).
"""
random_position(model) = notimplemented(model)

"""
    add_agent_to_space!(agent, model)
Add the agent to the underlying space structure at the agent's own position.
This function is called after the agent is already inserted into the model dictionary
and `maxid` has been updated. This function is NOT part of the public API.
"""
add_agent_to_space!(agent, model) = notimplemented(model)

"""
    remove_agent_from_space!(agent, model)
Remove the agent from the underlying space structure.
This function is called after the agent is already removed from the model container.
This function is NOT part of the public API.
"""
remove_agent_from_space!(agent, model) = notimplemented(model)

#######################################################################################
# %% IMPLEMENT: Neighbors and stuff
#######################################################################################
"""
    nearby_ids(position, model::ABM, r = 1; kwargs...) → ids

Return an iterable over the IDs of the agents within distance `r` (inclusive) from the given
`position`. The `position` must match type with the spatial structure of the `model`.
The specification of what "distance" means depends on the space, hence it is explained
in each space's documentation string. Keyword arguments are space-specific and also
described in each space's documentation string.

`nearby_ids` always includes IDs with 0 distance to `position`.
"""
nearby_ids(position, model, r = 1) = notimplemented(model)

"""
    nearby_positions(position, model::ABM{<:DiscreteSpace}, r=1; kwargs...)

Return an iterable of all positions within "radius" `r` of the given `position`
(which excludes given `position`).
The `position` must match type with the spatial structure of the `model`.

The value of `r` and possible keywords operate identically to [`nearby_ids`](@ref).

This function only exists for discrete spaces with a finite amount of positions.

    nearby_positions(position, model::ABM{<:OpenStreetMapSpace}; kwargs...) → positions

For [`OpenStreetMapSpace`](@ref) this means "nearby intersections" and operates directly
on the underlying graph of the OSM, providing the intersection nodes nearest to the
given position.
"""
nearby_positions(position, model, r = 1) = notimplemented(model)

#######################################################################################
# %% OPTIONAL IMPLEMENT
#######################################################################################
plan_route!(agent, dest, model_or_pathfinder; kwargs...) =
    notimplemented(model_or_pathfinder)

plan_best_route!(agent, dests, model_or_pathfinder; kwargs...) =
    notimplemented(model_or_pathfinder)

# """
#     move_along_route!(agent, model, args...; kwargs...)
# Move `agent` along the route planned for it. Used in situations like path-finding
# or open street map space movement.
# """
move_along_route!(agent, model, args...; kwargs...) = notimplemented(model)

"""
    is_stationary(agent, model)
Return `true` if agent has reached the end of its route, or no route
has been set for it. Used in setups where using [`move_along_route!`](@ref) is valid.
"""
is_stationary(agent, model) = notimplemented(model)

#######################################################################################
# %% Space agnostic removing and moving
#######################################################################################
"""
    move_agent!(agent [, pos], model::ABM) → agent

Move agent to the given position, or to a random one if a position is not given.
`pos` must have the appropriate position type depending on the space type.

The agent's position is updated to match `pos` after the move.
"""
function move_agent!(agent::A, pos::ValidPos, model::ABM{<:AbstractSpace,A}) where {A<:AbstractAgent}
    remove_agent_from_space!(agent, model)
    agent.pos = pos
    add_agent_to_space!(agent, model)
    return agent
end
function move_agent!(agent, model::ABM)
    move_agent!(agent, random_position(model), model)
end

"""
    remove_agent!(agent::AbstractAgent, model::ABM)
    remove_agent!(id::Int, model::ABM)

Remove an agent from the model.
"""
function remove_agent!(a::AbstractAgent, model::ABM)
    remove_agent_from_model!(a, model)
    remove_agent_from_space!(a, model)
end
remove_agent!(id::Integer, model::ABM) = remove_agent!(model[id], model)

"""
    remove_all!(model::ABM)
Remove all the agents of the model.
"""
function remove_all!(model::ABM)
    for a in allagents(model)
        remove_agent!(a, model)
    end
    model.maxid[] = 0
end

"""
    remove_all!(model::ABM, n::Int)
Remove the agents whose IDs are larger than n.
"""
function remove_all!(model::ABM, n::Integer)
    for id in allids(model)
        id > n && remove_agent!(id, model)
    end
    model.maxid[] = n
end


"""
    remove_all!(model::ABM, IDs)
Remove the agents with the given IDs.
"""
function remove_all!(model::ABM, ids)
    for id in ids
        remove_agent!(id, model)
    end
end

"""
    remove_all!(model::ABM, f::Function)
Remove all agents where the function `f(agent)` returns `true`.
"""
function remove_all!(model::ABM, f::Function)
    for a in allagents(model)
        f(a) && remove_agent!(a, model)
    end
end

#######################################################################################
# %% Space agnostic adding
#######################################################################################
"""
    add_agent_pos!(agent::AbstractAgent, model::ABM) → agent
Add the agent to the `model` at the agent's own position.
"""
function add_agent_pos!(agent::AbstractAgent, model::ABM)
    add_agent_to_model!(agent, model)
    add_agent_to_space!(agent, model)
    return agent
end

"""
    add_agent!(agent::AbstractAgent [, pos], model::ABM) → agent
Add the `agent` to the model in the given position.
If `pos` is not given, the `agent` is added to a random position.
The `agent`'s position is always updated to match `position`, and therefore for `add_agent!`
the position of the `agent` is meaningless. Use [`add_agent_pos!`](@ref) to use
the `agent`'s position.

The type of `pos` must match the underlying space position type.
"""
function add_agent!(agent::AbstractAgent, model::ABM)
    agent.pos = random_position(model)
    add_agent_pos!(agent, model)
end

function add_agent!(agent::AbstractAgent, pos::ValidPos, model::ABM)
    agent.pos = pos
    add_agent_pos!(agent, model)
end

"""
    add_agent!([pos,] model::ABM, args...; kwargs...) → newagent
Create and add a new agent to the model using the constructor of the agent type of the model.
Optionally provide a position to add the agent to as *first argument*, which must
match the space position type.

This function takes care of setting the agent's id *and* position.
The extra provided `args...` and `kwargs...` are propagated to other fields
of the agent constructor (see example below).

    add_agent!([pos,] A::Type, model::ABM, args...; kwargs...) → newagent

Use this version for mixed agent models, with `A` the agent type you wish to create
(to be called as `A(id, pos, args...; kwargs...)`), because it is otherwise not possible
to deduce a constructor for `A`.

## Example
```julia
using Agents
mutable struct Agent <: AbstractAgent
    id::Int
    pos::Int
    w::Float64
    k::Bool
end
Agent(id, pos; w=0.5, k=false) = Agent(id, pos, w, k) # keyword constructor
model = ABM(Agent, GraphSpace(complete_digraph(5)))

add_agent!(model, 1, 0.5, true) # incorrect: id/pos is set internally
add_agent!(model, 0.5, true) # correct: w becomes 0.5
add_agent!(5, model, 0.5, true) # add at position 5, w becomes 0.5
add_agent!(model; w = 0.5) # use keywords: w becomes 0.5, k becomes false
```
"""
function add_agent!(model::ABM{S,A}, properties...; kwargs...) where {S,A<:AbstractAgent}
    add_agent!(A, model, properties...; kwargs...)
end

function add_agent!(A::Type{<:AbstractAgent}, model::ABM, properties...; kwargs...)
    add_agent!(random_position(model), A, model, properties...; kwargs...)
end

function add_agent!(
    pos::ValidPos,
    model::ABM{S,A},
    properties...;
    kwargs...,
) where {S,A<:AbstractAgent}
    add_agent!(pos, A, model, properties...; kwargs...)
end

# lowest level:
function add_agent!(
    pos::ValidPos,
    A::Type{<:AbstractAgent},
    model::ABM,
    properties...;
    kwargs...,
)
    id = nextid(model)
    newagent = A(id, pos, properties...; kwargs...)
    add_agent_pos!(newagent, model)
end

#######################################################################################
# %% Space agnostic neighbors
#######################################################################################
"""
    nearby_ids(agent::AbstractAgent, model::ABM, r=1)

Same as `nearby_ids(agent.pos, model, r)` but the iterable *excludes* the given
`agent`'s id.
"""
function nearby_ids(agent::A, model::ABM, r = 1; kwargs...) where {A<:AbstractAgent}
    all = nearby_ids(agent.pos, model, r; kwargs...)
    Iterators.filter(i -> i ≠ agent.id, all)
end

"""
    nearby_positions(agent::AbstractAgent, model::ABM, r=1)

Same as `nearby_positions(agent.pos, model, r)`.
"""
function nearby_positions(
    agent::A,
    model::ABM{S,A},
    r = 1;
    kwargs...,
) where {S,A<:AbstractAgent}
    nearby_positions(agent.pos, model, r; kwargs...)
end

"""
    nearby_agents(agent, model::ABM, r = 1; kwargs...) -> agent

Return an iterable of the agents near the position of the given `agent`.

The value of the argument `r` and possible keywords operate identically to [`nearby_ids`](@ref).
"""
nearby_agents(a, model, r = 1; kwargs...) =
    (model[id] for id in nearby_ids(a, model, r; kwargs...))

"""
    random_nearby_id(agent, model::ABM, r = 1; kwargs...) → id

Return the `id` of a random agent near the position of the given `agent` using an optimized
algorithm from [Reservoir sampling](https://en.wikipedia.org/wiki/Reservoir_sampling#An_optimal_algorithm).
Return `nothing` if no agents are nearby.

The value of the argument `r` and possible keywords operate identically to [`nearby_ids`](@ref).
"""
function random_nearby_id(a, model, r = 1; kwargs...)
    # Uses Reservoir sampling (https://en.wikipedia.org/wiki/Reservoir_sampling)
    iter = nearby_ids(a, model, r; kwargs...)

    res = iterate(iter)
    isnothing(res) && return    # `iterate` returns `nothing` when it ends

    choice, state = res         # random ID to return, and the state of the iterator
    w = max(rand(model.rng), eps())  # rand returns in range [0,1)

    skip_counter = 0            # skip entries in the iterator
    while !isnothing(state) && !isnothing(iter)
        if skip_counter == 0
            choice, state = res
            skip_counter = floor(log(rand(model.rng)) / log(1 - w))
            w *= max(rand(model.rng), eps())
        else
            _, state = res
            skip_counter -= 1
        end

        res = iterate(iter, state)
        isnothing(res) && break
    end

    return choice
end

"""
    random_nearby_agent(agent, model::ABM, r = 1; kwargs...) → agent

Return a random agent near the position of the given `agent` or `nothing` if no agent
is nearby.

The value of the argument `r` and possible keywords operate identically to [`nearby_ids`](@ref).
"""
function random_nearby_agent(a, model, r = 1; kwargs...)
    id = random_nearby_id(a, model, r; kwargs...)
    isnothing(id) && return
    return model[id]
end

"""
    random_nearby_position(position, model::ABM, r=1; kwargs...) → position

Return a random position near the given `position`. Return `nothing` if the space doesn't allow for nearby positions.

The value of the argument `r` and possible keywords operate identically to [`nearby_positions`](@ref).
"""
function random_nearby_position(pos, model, r=1; kwargs...)
    # Uses the same Reservoir Sampling algorithm than nearby_ids
    iter = nearby_positions(pos, model, r; kwargs...)

    res = iterate(iter)
    isnothing(res) && return nothing  # `iterate` returns `nothing` when it ends

    choice, state = res         # random position to return, and the state of the iterator
    w = max(rand(model.rng), eps())  # rand returns in range [0,1)

    skip_counter = 0            # skip entries in the iterator
    while !isnothing(state) && !isnothing(iter)
        if skip_counter == 0
            choice, state = res
            skip_counter = floor(log(rand(model.rng)) / log(1 - w))
            w *= max(rand(model.rng), eps())
        else
            _, state = res
            skip_counter -= 1
        end

        res = iterate(iter, state)
        isnothing(res) && break
    end

    return choice
end
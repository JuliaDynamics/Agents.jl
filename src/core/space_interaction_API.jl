#=
This file establishes the agent-space interaction API.
All space types should implement this API (and be subtypes of `AbstractSpace`)
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
    add_agent_own_pos!,
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
    nearby_ids(pos, model::ABM, r = 1; kwargs...) → ids

Return an iterable over the IDs of the agents within distance `r` (inclusive) from the given
position. The position must match type with the spatial structure of the `model`.
The specification of what "distance" means depends on the space, hence it is explained
in each space's documentation string. Keyword arguments are space-specific and also
described in each space's documentation string.

`nearby_ids` always includes IDs with 0 distance to `pos`.
"""
nearby_ids(pos, model, r = 1) = notimplemented(model)

"""
    nearby_positions(pos, model::ABM{<:DiscreteSpace}, r=1; kwargs...)

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
nearby_positions(pos, model, r = 1) = notimplemented(model)

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
function move_agent!(agent::AbstractAgent, pos::ValidPos, model::ABM)
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
    remove_all_from_space!(model)
    remove_all_from_model!(model)
    getfield(model, :maxid)[] = 0
end

"""
    remove_all!(model::ABM, n::Int)
Remove the agents whose IDs are larger than n.
"""
function remove_all!(model::ABM, n::Integer)
    for id in allids(model)
        id > n && remove_agent!(id, model)
    end
    getfield(model, :maxid)[] = n
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
    add_agent_own_pos!(agent::AbstractAgent, model::ABM) → agent

Add the agent to the `model` at the agent's own position.
"""
function add_agent_own_pos!(agent::AbstractAgent, model::ABM)
    add_agent_to_model!(agent, model)
    add_agent_to_space!(agent, model)
    return agent
end

"""
    add_agent!(agent::AbstractAgent [, pos], model::ABM) → agent

Add the `agent` to the model in the given position.
If `pos` is not given, the `agent` is added to a random position.
The `agent`'s position is always updated to match `position`, and therefore for `add_agent!`
the position of the `agent` is meaningless. Use [`add_agent_own_pos!`](@ref) to use
the `agent`'s position.
The type of `pos` must match the underlying space position type.
"""
function add_agent!(agent::AbstractAgent, model::ABM)
    agent.pos = random_position(model)
    add_agent_own_pos!(agent, model)
end

function add_agent!(agent::AbstractAgent, pos::ValidPos, model::ABM)
    agent.pos = pos
    add_agent_own_pos!(agent, model)
end

"""
    add_agent!([pos,] model::ABM, args...) → newagent
    add_agent!([pos,] model::ABM; kwargs...) → newagent

Use one of these two versions to create and add a new agent to the model using the
constructor of the agent type of the model. Optionally provide a position to add
the agent to as *first argument*, which must match the space position type.

This function takes care of setting the agent id *and* position.
The extra provided `args...` or `kwargs...` are propagated to other fields
of the agent constructor (see example below). Mixing `args...` and `kwargs...`
is not possible, only one of the two can be used to set the fields.

    add_agent!([pos,] A::Type, model::ABM, args...) → newagent
    add_agent!([pos,] A::Type, model::ABM; kwargs...) → newagent

Use one of these two versions for mixed agent models, with `A` the agent type you wish to create,
because it is otherwise not possible to deduce a constructor for `A`.

## Example

```julia
using Agents
@agent struct Agent(GraphAgent)
    w::Float64 = 0.1
    k::Bool = false
end
model = StandardABM(Agent, GraphSpace(complete_digraph(5)))

add_agent!(model, 1, 0.5, true) # incorrect: id/pos is set internally
add_agent!(model, 0.5, true) # correct: w becomes 0.5
add_agent!(5, model, 0.5, true) # add at position 5, w becomes 0.5
add_agent!(model; w = 0.5) # use keywords: w becomes 0.5, k becomes false
```
"""
function add_agent!(model::ABM, args::Vararg{Any, N}; kwargs...) where {N}
    A = agenttype(model)
    add_agent!(A, model, args...; kwargs...)
end

function add_agent!(A::Type, model::ABM, 
        args::Vararg{Any, N}; kwargs...) where {N}
    add_agent!(random_position(model), A, model, args...; kwargs...)
end

function add_agent!(
    pos::ValidPos,
    model::ABM,
    args::Vararg{Any, N};
    kwargs...,
) where {N}
    A = agenttype(model)
    add_agent!(pos, A, model, args...; kwargs...)
end

# lowest level - actually constructs the agent
function add_agent!(
    pos::ValidPos,
    A::Type,
    model::ABM,
    args::Vararg{Any, N};
    kwargs...,
) where {N}
    id = nextid(model)
    if isempty(kwargs)
        newagent = A(id, pos, args...)
    else
        newagent = A(; id = id, pos = pos, kwargs...)
    end
    add_agent_own_pos!(newagent, model)
end

#######################################################################################
# %% Space agnostic neighbors
#######################################################################################
"""
    nearby_ids(agent::AbstractAgent, model::ABM, r=1)

Same as `nearby_ids(agent.pos, model, r)` but the iterable *excludes* the given
`agent`'s id.
"""
function nearby_ids(agent::AbstractAgent, model::ABM, r = 1; kwargs...)
    all = nearby_ids(agent.pos, model, r; kwargs...)
    Iterators.filter(i -> i ≠ agent.id, all)
end

"""
    nearby_positions(agent::AbstractAgent, model::ABM, r=1)

Same as `nearby_positions(agent.pos, model, r)`.
"""
function nearby_positions(agent::AbstractAgent, model::ABM, r = 1; kwargs...)
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
    random_nearby_id(agent, model::ABM, r = 1, f = nothing, alloc = false; kwargs...) → id
Return the `id` of a random agent near the position of the given `agent`.

Return `nothing` if no agents are nearby.

The value of the argument `r` and possible keywords operate identically to [`nearby_ids`](@ref).

A filter function `f(id)` can be passed so that to restrict the sampling on only those ids for which
the function returns `true`. The argument `alloc` can be used if the filtering condition
is expensive since in this case the allocating version can be more performant.
`nothing` is returned if no nearby id satisfies `f`.

For discrete spaces, use [`random_id_in_position`](@ref) instead to return a random id at a given
position.

This function, as all the other methods which sample from lazy iterators, uses an optimized
algorithm which doesn't require to collect all elements to just sample one of them.
"""
function random_nearby_id(a, model, r = 1, f = nothing, alloc = false; kwargs...)
    iter = nearby_ids(a, model, r; kwargs...)
    if isnothing(f)
        return IteratorSampling.itsample(abmrng(model), iter; method=:alg_R)
    else
        if alloc
            return sampling_with_condition_single(iter, f, model)
        else
            iter_filtered = Iterators.filter(id -> f(id), iter)
            return IteratorSampling.itsample(abmrng(model), iter_filtered; method=:alg_R)
        end
    end
end

"""
    random_nearby_agent(agent, model::ABM, r = 1, f = nothing, alloc = false; kwargs...) → agent
Return a random agent near the position of the given `agent` or `nothing` if no agent
is nearby.

The value of the argument `r` and possible keywords operate identically to [`nearby_ids`](@ref).

A filter function `f(agent)` can be passed so that to restrict the sampling on only those agents for which
the function returns `true`. The argument `alloc` can be used if the filtering condition
is expensive since in this case the allocating version can be more performant.
`nothing` is returned if no nearby agent satisfies `f`.

For discrete spaces, use [`random_agent_in_position`](@ref) instead to return a random agent at a given
position.
"""
function random_nearby_agent(a, model, r = 1, f = nothing, alloc = false; kwargs...)
    iter_ids = nearby_ids(a, model, r; kwargs...)
    if isnothing(f)
        id = IteratorSampling.itsample(abmrng(model), iter_ids; method=:alg_R)
    else
        if alloc
            id = sampling_with_condition_single(iter_ids, f, model, id -> model[id])
        else
            iter_filtered = Iterators.filter(id -> f(model[id]), iter_ids)
            id = IteratorSampling.itsample(abmrng(model), iter_filtered; method=:alg_R)
        end
    end
    isnothing(id) && return nothing
    return model[id]
end

"""
    random_nearby_position(pos, model::ABM, r=1, f = nothing, alloc = false; kwargs...) → position
Return a random position near the given position.
Return `nothing` if the space doesn't allow for nearby positions.

The value of the argument `r` and possible keywords operate identically to [`nearby_positions`](@ref).

A filter function `f(pos)` can be passed so that to restrict the sampling on only those positions for which
the function returns `true`. The argument `alloc` can be used if the filtering condition
is expensive since in this case the allocating version can be more performant.
`nothing` is returned if no nearby position satisfies `f`.
"""
function random_nearby_position(pos, model, r=1, f = nothing, alloc = false; kwargs...)
    iter = nearby_positions(pos, model, r; kwargs...)
    if isnothing(f)
        return IteratorSampling.itsample(abmrng(model), iter; method=:alg_R)
    else
        if alloc
            return sampling_with_condition_single(iter, f, model)
        else
            iter_filtered = Iterators.filter(pos -> f(pos), iter)
            return IteratorSampling.itsample(abmrng(model), iter_filtered; method=:alg_R)
        end
    end
end

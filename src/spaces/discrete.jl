#=
This file implements functions shared by all discrete spaces.
Discrete spaces are by definition spaces with a finite amount of possible positions.

All these functions are granted "for free" to discrete spaces by simply extending:
- positions(space)
- ids_in_position(position, model)

Notice that the default version of the remaining functions assumes that
agents are stored in a field `stored_ids` of the space.
=#

export positions, npositions, ids_in_position, agents_in_position,
       empty_positions, random_empty, has_empty_positions, empty_nearby_positions,
       random_id_in_position, random_agent_in_position


positions(model::ABM) = positions(abmspace(model))
"""
    positions(model::ABM{<:DiscreteSpace}) → ns
Return an iterator over all positions of a model with a discrete space.

    positions(model::ABM{<:DiscreteSpace}, by::Symbol) → ns
Return all positions of a model with a discrete space, sorting them
using the argument `by` which can be:
* `:random` - randomly sorted
* `:population` - positions are sorted depending on how many agents they accommodate.
  The more populated positions are first.
"""
function positions(model::ABM{<:DiscreteSpace}, by::Symbol)
    n = collect(positions(model))
    itr = vec(n)
    if by == :random
        shuffle!(abmrng(model), itr)
    elseif by == :population
        sort!(itr, by = i -> length(ids_in_position(i, model)), rev = true)
    else
        error("unknown `by`")
    end
    return itr
end

"""
    npositions(model::ABM{<:DiscreteSpace})

Return the number of positions of a model with a discrete space.
"""
npositions(model::ABM) = npositions(abmspace(model))

"""
    ids_in_position(position, model::ABM{<:DiscreteSpace})
    ids_in_position(agent, model::ABM{<:DiscreteSpace})

Return the ids of agents in the position corresponding to `position` or position
of `agent`.
"""
ids_in_position(agent::A, model) where {A<:AbstractAgent} =
    ids_in_position(agent.pos, model)

"""
    agents_in_position(position, model::ABM{<:DiscreteSpace})
    agents_in_position(agent, model::ABM{<:DiscreteSpace})

Return an iterable of the agents in `position``, or in the position of `agent`.
"""
agents_in_position(agent::A, model) where {A<:AbstractAgent} =
    agents_in_position(agent.pos, model)
agents_in_position(pos, model) = (model[id] for id in ids_in_position(pos, model))

"""
    empty_positions(model)

Return a list of positions that currently have no agents on them.
"""
function empty_positions(model::ABM{<:DiscreteSpace})
    Iterators.filter(i -> length(ids_in_position(i, model)) == 0, positions(model))
end

"""
    isempty(position, model::ABM{<:DiscreteSpace})
Return `true` if there are no agents in `position`.
"""
Base.isempty(pos, model::ABM) = isempty(ids_in_position(pos, model))

"""
    has_empty_positions(model::ABM{<:DiscreteSpace})
Return `true` if there are any positions in the model without agents.
"""
function has_empty_positions(model::ABM{<:DiscreteSpace})
    return any(pos -> isempty(pos, model), positions(model))
end

"""
    random_empty(model::ABM{<:DiscreteSpace})
Return a random position without any agents, or `nothing` if no such positions exist.
"""
function random_empty(model::ABM{<:DiscreteSpace}, cutoff = 0.998)
    # This switch assumes the worst case (for this algorithm) of one
    # agent per position, which is not true in general but is appropriate
    # here.
    if clamp(nagents(model) / npositions(model), 0.0, 1.0) < cutoff
        # 0.998 has been benchmarked as a performant branching point
        # It sits close to where the maximum return time is better
        # than the code in the else loop runs. So we guarantee
        # an increase in performance overall, not just when we
        # get lucky with the random rolls.
        while true
            pos = random_position(model)
            isempty(pos, model) && return pos
        end
    else
        empty = empty_positions(model)
        return resorvoir_sampling_single(empty, model)
    end
end

"""
    empty_nearby_positions(pos, model::ABM{<:DiscreteSpace}, r = 1; kwargs...)
    empty_nearby_positions(agent, model::ABM{<:DiscreteSpace}, r = 1; kwargs...)

Return an iterable of all empty positions within radius `r` from the given position or the given agent.

The value of `r` and possible keywords operate identically to [`nearby_positions`](@ref).
"""
function empty_nearby_positions(agent::AbstractAgent, model, r = 1; kwargs...)
    return empty_nearby_positions(agent.pos, model, r; kwargs...)
end
function empty_nearby_positions(pos, model, r = 1; kwargs...)
    return Iterators.filter(pos -> isempty(pos, model), nearby_positions(pos, model, r; kwargs...))
end

"""
    random_id_in_position(pos, model::ABM, [f, alloc = false]) → id
Return a random id in the position specified in `pos`.

A filter function `f(id)` can be passed so that to restrict the sampling on only those agents
for which the function returns `true`. The argument `alloc` can be used if the filtering condition
is expensive since in this case the allocating version can be more performant.
`nothing` is returned if no nearby position satisfies `f`.

Use [`random_nearby_id`](@ref) instead to return the `id` of a random agent near the position of a
given `agent`.
"""
function random_id_in_position(pos, model)
    ids = ids_in_position(pos, model)
    isempty(ids) && return nothing
    return rand(abmrng(model), ids)
end
function random_id_in_position(pos, model, f, alloc = false)
    iter_ids = ids_in_position(pos, model)
    if alloc
        return sampling_with_condition_single(iter_ids, f, model)
    else
        iter_filtered = Iterators.filter(id -> f(id), iter_ids)
        return resorvoir_sampling_single(iter_filtered, model)
    end
end

"""
    random_agent_in_position(pos, model::ABM, [f, alloc = false]) → agent
Return a random agent in the position specified in `pos`.

A filter function `f(agent)` can be passed so that to restrict the sampling on only those agents
for which the function returns `true`. The argument `alloc` can be used if the filtering condition
is expensive since in this case the allocating version can be more performant. 
`nothing` is returned if no nearby position satisfies `f`.

Use [`random_nearby_agent`](@ref) instead to return a random agent near the position of a given `agent`.
"""
function random_agent_in_position(pos, model)
    id = random_id_in_position(pos, model)
    isnothing(id) && return nothing
    return model[id]
end
function random_agent_in_position(pos, model, f, alloc = false)
    iter_ids = ids_in_position(pos, model)
    if alloc
        return sampling_with_condition_agents_single(iter_ids, f, model)
    else
        iter_filtered = Iterators.filter(id -> f(model[id]), iter_ids)
        id = resorvoir_sampling_single(iter_filtered, model)
        isnothing(id) && return nothing
        return model[id]
    end
end

#######################################################################################
# Discrete space extra agent adding stuff
#######################################################################################
export add_agent_single!, fill_space!, move_agent_single!,swap_agents!

"""
    add_agent_single!(model::ABM{<:DiscreteSpace}, properties...; kwargs...)
Same as `add_agent!(model, properties...; kwargs...)` but ensures that it adds an agent
into a position with no other agents (does nothing if no such position exists).
"""
function add_agent_single!(model::ABM{<:DiscreteSpace}, properties::Vararg{Any, N}; kwargs...) where {N}
    position = random_empty(model)
    isnothing(position) && return nothing
    agent = add_agent!(position, model, properties...; kwargs...)
    return agent
end

"""
    add_agent_single!(A, model::ABM{<:DiscreteSpace}, properties...; kwargs...)
Same as `add_agent!(A, model, properties...; kwargs...)` but ensures that it adds an agent
into a position with no other agents (does nothing if no such position exists).
"""
function add_agent_single!(A::Type{<:AbstractAgent}, model::ABM, properties::Vararg{Any, N}; kwargs...) where {N}
    position = random_empty(model)
    isnothing(position) && return nothing
    agent = add_agent!(position, A, model, properties...; kwargs...)
    return agent
end

"""
    fill_space!([A ,] model::ABM{<:DiscreteSpace,A}, args...; kwargs...)
    fill_space!([A ,] model::ABM{<:DiscreteSpace,A}, f::Function; kwargs...)
Add one agent to each position in the model's space. Similarly with [`add_agent!`](@ref),
the function creates the necessary agents and
the `args...; kwargs...` are propagated into agent creation.
If instead of `args...` a function `f` is provided, then `args = f(pos)` is the result of
applying `f` where `pos` is each position (tuple for grid, integer index for graph).

An optional first argument is an agent **type** to be created, and targets mixed agent
models where the agent constructor cannot be deduced (since it is a union).
"""
fill_space!(model::ABM{S,A}, args::Vararg{Any, N}; kwargs...) where {N,S,A<:AbstractAgent} =
    fill_space!(A, model, args...; kwargs...)

function fill_space!(
    ::Type{A},
    model::ABM{<:DiscreteSpace,U},
    args::Vararg{Any, N};
    kwargs...,
) where {N,A<:AbstractAgent,U<:AbstractAgent}
    for p in positions(model)
        id = nextid(model)
        add_agent_pos!(A(id, p, args...; kwargs...), model)
    end
    return model
end

function fill_space!(
    ::Type{A},
    model::ABM{<:DiscreteSpace,U},
    f::Function;
    kwargs...,
) where {A<:AbstractAgent,U<:AbstractAgent}
    for p in positions(model)
        id = nextid(model)
        args = f(p)
        add_agent_pos!(A(id, p, args...; kwargs...), model)
    end
    return model
end

"""
    move_agent_single!(agent, model::ABM{<:DiscreteSpace}; cutoff) → agent

Move agent to a random position while respecting a maximum of one agent
per position. If there are no empty positions, the agent won't move.

The keyword `cutoff = 0.998` is sent to [`random_empty`](@ref).
"""
function move_agent_single!(
    agent::A,
    model::ABM{<:DiscreteSpace,A};
    cutoff = 0.998,
) where {A<:AbstractAgent}
    position = random_empty(model, cutoff)
    isnothing(position) && return nothing
    move_agent!(agent, position, model)
    return agent
end

"""
    swap_agents!(agent1, agent2, model::ABM{<:DiscreteSpace})

Swaps agents function used for swapping the postion of two agents.
"""
function swap_agents!(agent1, agent2, model::ABM{<:DiscreteSpace})
    pos_a = agent1.pos    
    pos_b = agent2.pos

    remove_agent_from_space!(agent1, model)
    remove_agent_from_space!(agent2, model)
    pos_a, pos_b = pos_b, pos_a
    add_agent_to_space!(agent1, model)    
    add_agent_to_space!(agent2, model)

    return nothing
end
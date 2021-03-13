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

TODO: do_checks needs to be updated for each new space type
=#
export move_agent!,
    add_agent!,
    add_agent_pos!,
    kill_agent!,
    kill_agents!,
    genocide!,
    random_position,
    nearby_positions,
    nearby_ids,
    nearby_agents

notimplemented(model) =
    error("Not implemented for space type $(nameof(typeof(model.space)))")

#######################################################################################
# %% IMPLEMENT
#######################################################################################
"""
    random_position(model) → pos
Return a random position in the model's space (always with appropriate Type).
"""
random_position(model) = notimplemented(model)

"""
    move_agent!(agent [, pos], model::ABM) → agent

Move agent to the given position, or to a random one if a position is not given.
`pos` must have the appropriate position type depending on the space type.

The agent's position is updated to match `pos` after the move.
"""
move_agent!(agent, pos, model) = notimplemented(model)

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
This function is called after the agent is already removed from the model dictionary
This function is NOT part of the public API.
"""
remove_agent_from_space!(agent, model) = notimplemented(model)

#######################################################################################
# %% IMPLEMENT: Neighbors and stuff
#######################################################################################
"""
    nearby_ids(position, model::ABM, r; kwargs...) → ids

Return an iterable of the ids of the agents within "radius" `r` of the given `position`
(which must match type with the spatial structure of the `model`).

What the "radius" means depends on the space type:
- `GraphSpace`: the degree of neighbors in the graph (thus `r` is always an integer).
  For example, for `r=2` include first and second degree neighbors.
- `GridSpace, ContinuousSpace`: Either Chebyshev (also called Moore) or Euclidean distance,
  in the space of cartesian indices.
- `GridSpace` can also take a tuple argument, e.g. `r = (5, 2)` for a 2D space, which
extends 5 positions in the x direction and 2 in the y. Only possible with Chebyshev
spaces.
- `OpenStreetMapSpace`: `r` is equivalent with distance (in meters) neeeded to be travelled
  according to existing roads in order to reach given `position`.

## Keywords
Keyword arguments are space-specific.
For `GraphSpace` the keyword `neighbor_type=:default` can be used to select differing
neighbors depending on the underlying graph directionality type.
- `:default` returns neighbors of a vertex (position). If graph is directed, this is equivalent
  to `:out`. For undirected graphs, all options are equivalent to `:out`.
- `:all` returns both `:in` and `:out` neighbors.
- `:in` returns incoming vertex neighbors.
- `:out` returns outgoing vertex neighbors.

For `ContinuousSpace`, the keyword `exact=false` controls whether the found neighbors are
exactly accurate or approximate (with approximate always being a strict over-estimation),
see [`ContinuousSpace`](@ref).
"""
nearby_ids(position, model, r = 1) = notimplemented(model)

"""
    nearby_positions(position, model::ABM, r=1; kwargs...) → positions

Return an iterable of all positions within "radius" `r` of the given `position`
(which excludes given `position`).
The `position` must match type with the spatial structure of the `model`.

The value of `r` and possible keywords operate identically to [`nearby_ids`](@ref).

This function only makes sense for discrete spaces with a finite amount of positions.

    nearby_positions(position, model::ABM{<:OpenStreetMapSpace}; kwargs...) → positions

For [`OpenStreetMapSpace`](@ref) this means "nearby intersections" and operates directly
on the underlying graph of the OSM, providing the intersection nodes nearest to the
given position.
"""
nearby_positions(position, model, r = 1) = notimplemented(model)

#######################################################################################
# %% Space agnostic killing and moving
#######################################################################################
"""
    kill_agent!(agent::AbstractAgent, model::ABM)
    kill_agent!(id::Int, model::ABM)

Remove an agent from the model.
"""
function kill_agent!(a::AbstractAgent, model::ABM)
    delete!(model.agents, a.id)
    remove_agent_from_space!(a, model)
end

kill_agent!(id::Integer, model::ABM) = kill_agent!(model[id], model)

"""
    kill_agents!(ids, model::ABM)

Remove all agents with then given ids agent from the model.
"""
function kill_agents!(ids, model::ABM)
    for i in ids
        kill_agent!(i, model)
    end
end

"""
    genocide!(model::ABM)
Kill all the agents of the model.
"""
function genocide!(model::ABM)
    for a in allagents(model)
        kill_agent!(a, model)
    end
    model.maxid[] = 0
end

"""
    genocide!(model::ABM, n::Int)
Kill the agents of the model whose IDs are larger than n.
"""
function genocide!(model::ABM, n::Integer)
    for (k, v) in model.agents
        k > n && kill_agent!(v, model)
    end
    model.maxid[] = n
end

"""
    genocide!(model::ABM, f::Function)
Kill all agents where the function `f(agent)` returns `true`.
"""
function genocide!(model::ABM, f::Function)
    for a in allagents(model)
        f(a) && kill_agent!(a, model)
    end
end

# Notice: this function is overwritten for continuous space and instead implements
# the Euler scheme.
function move_agent!(agent, model::ABM)
    move_agent!(agent, random_position(model), model)
end

#######################################################################################
# %% Space agnostic adding
#######################################################################################
"""
    add_agent_pos!(agent::AbstractAgent, model::ABM) → agent
Add the agent to the `model` at the agent's own position.
"""
function add_agent_pos!(agent::AbstractAgent, model::ABM)
    model[agent.id] = agent
    model.maxid[] < agent.id && (model.maxid[] = agent.id)
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
function nearby_ids(
    agent::A,
    model::ABM{S,A},
    args...;
    kwargs...,
) where {S,A<:AbstractAgent}
    all = nearby_ids(agent.pos, model, args...; kwargs...)
    Iterators.filter(i -> i ≠ agent.id, all)
end

"""
    nearby_positions(agent::AbstractAgent, model::ABM, r=1)

Same as `nearby_positions(agent.pos, model, r)`.
"""
function nearby_positions(
    agent::A,
    model::ABM{S,A},
    args...;
    kwargs...,
) where {S,A<:AbstractAgent}
    nearby_positions(agent.pos, model, args...; kwargs...)
end

"""
    nearby_agents(agent, model::ABM, args...; kwargs...) -> agent

Return an iterable of the agents near the position of the given `agent`.

The value of the argument `r` and possible keywords operate identically to [`nearby_ids`](@ref).
"""
nearby_agents(a, model, args...; kwargs...) =
    (model[id] for id in nearby_ids(a, model, args...; kwargs...))

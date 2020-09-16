#=
This file establishes the agent-space interaction API.
All space types should implement this API.
Some functions DO NOT need to be implemented for every space, they are space agnostic.
These functions have complete source code here, while the functions that DO need to
be implemented for every space have only documentation strings here and an
error message.

In short: IMPLEMENT ALL FUNCTIONS IN SECTION "ABSOLUTELY IMPLEMENT", WITH SAME ARGUMENTS!
=#
export move_agent!,
    add_agent!,
    add_agent_pos!,
    kill_agent!,
    genocide!,
    nextid,
    fill_space!

notimplemented(model) = error("Not implemented for space type $(nameof(typeof(model.space)))")

#######################################################################################
# ABSOLUTELY IMPLEMENT!
#######################################################################################
"""
    kill_agent!(agent::AbstractAgent, model::ABM)
    kill_agent!(id::Int, model::ABM)

Remove an agent from model, and from the space if the model has a space.
"""
kill_agent!(a::AbstractAgent, model::ABM) = notimplemented(model)

"""
    random_position(model) → pos
Return a random position in the model's space (always with appropriate Type).
"""
random_position(model) = notimplemented(model)

"""
    move_agent!(agent [, pos], model::ABM) → agent

Move agent to the given position, or to a random one if a position is not given.
`pos` must be the appropriate position type depending on the space type.
"""
move_agent!(agent::A, pos, model::ABM{A}) where {A<:AbstractAgent} = notimplemented(model)

"""
    add_agent_pos!(agent::AbstractAgent, model::ABM) → agent
Add the agent to the `model` at the agent's own position.
"""
add_agent_pos!(agent::A, model::ABM) = notimplemented(model)


#######################################################################################
# Space agnostic
#######################################################################################
kill_agent!(id::Integer, model::ABM) = kill_agent!(model[id], model)

"""
    genocide!(model::ABM)
Kill all the agents of the model.
"""
function genocide!(model::ABM)
    for a in allagents(model)
        kill_agent!(a, model)
    end
end

"""
    genocide!(model::ABM, n::Int)
Kill the agents of the model whose IDs are larger than n.
"""
function genocide!(model::ABM, n::Integer)
    for (k, v) in model.agents
        k > n && kill_agent!(v, model)
    end
end

"""
    genocide!(model::ABM, f::Function)
Kill all agents where the function `f(agent)` returns `true`.
"""
genocide!(model::ABM, f::Function)
    for a in allagents(model)
        f(a) && kill_agent!(a, model)
    end
end

# Notice: this function is overwritten for continuous space and instead implements
# the Euler scheme.
function move_agent!(agent::A, model::ABM{A}) where {A<:AbstractAgent}
    move_agent!(agent, random_position(model), model)
end

#######################################################################################
# Space agnostic add_agent!
#######################################################################################
# function add_agent!(model::ABM, properties...; kwargs...)
#     add_agent!(random_position(model), model, properties...; kwargs...)
# end
# function add_agent!(pos, model::ABM{A}, properties...; kwargs...) where {A<:AbstractAgent}
#     id = nextid(model)
#     add_agent_pos!(A(id, pos, properties...; kwargs...), model)
# end
#
# add_agent!(a::AbstractAgent, model::ABM) = add_agent!(a, random_position(model), model)
# function add_agent!(a::AbstractAgent, pos, model::ABM)
#     a.pos = pos
#     add_agent_pos!(a, model)
# end
#


#######################################################################################
# Adding agents
#######################################################################################

"""
    add_agent_pos!(agent::AbstractAgent, model::ABM) → agent
Add the agent to the `model` at the agent's own position.
"""
function add_agent_pos!(agent::A, model::ABM{A,<:DiscreteSpace}) where {A<:AbstractAgent}
    model[agent.id] = agent
    nn = coord2vertex(agent.pos, model)
    push!(model.space.agent_positions[nn], agent.id)
    return model[agent.id]
end

"""
    add_agent!(agent::AbstractAgent [, position], model::ABM) → agent

Add the `agent` to the `position` in the space and to the list of agents.
If `position` is not given, the `agent` is added to a random position.
The `agent`'s position is always updated to match `position`, and therefore for `add_agent!`
the position of the `agent` is meaningless. Use [`add_agent_pos!`](@ref) to use
the `agent`'s position.
"""
function add_agent!(agent::A, model::ABM{A,<:DiscreteSpace}) where {A<:AbstractAgent}
    agent.pos = correct_pos_type(rand(1:nv(model)), model)
    add_agent_pos!(agent, model)
end


function add_agent!(
    agent::A,
    pos::NTuple{D,Integer},
    model::ABM{A,<:DiscreteSpace},
) where {A<:AbstractAgent,D}
    @assert isa(pos, typeof(agent.pos)) "Invalid position type for `pos`"
    agent.pos = pos
    add_agent_pos!(agent, model)
end

function add_agent!(
    agent::A,
    pos::Integer,
    model::ABM{A,<:DiscreteSpace},
) where {A<:AbstractAgent}
    agent.pos = correct_pos_type(pos, model)
    add_agent_pos!(agent, model)
end

"""
    add_agent!([pos,] model::ABM, args...; kwargs...)
Create and add a new agent to the model by constructing an agent of the
type of the `model`. Propagate all *extra* positional arguments and
keyword arguemts to the agent constructor.

Notice that this function takes care of setting the agent's id *and* position and thus
`args...` and `kwargs...` are propagated to other fields the agent has.

Optionally provide a position to add the agent to as *first argument*.

## Example
```julia
using Agents
mutable struct Agent <: AbstractAgent
    id::Int
    pos::Int
    w::Float64
    k::Bool
end
Agent(id, pos; w, k) = Agent(id, pos, w, k) # keyword constructor
model = ABM(Agent, GraphSpace(complete_digraph(5)))

add_agent!(model, 1, 0.5, true) # incorrect: id/pos is set internally
add_agent!(model, 0.5, true) # correct: w becomes 0.5
add_agent!(5, model, 0.5, true) # add at node 5, w becomes 0.5
add_agent!(model; w = 0.5, k = true) # use keywords: w becomes 0.5
```
"""
function add_agent!(
        model::ABM{A,<:DiscreteSpace},
        properties...;
        kwargs...,
    ) where {A<:AbstractAgent}
    add_agent!(rand(1:nv(model)), model, properties...; kwargs...)
end

function add_agent!(
        node,
        model::ABM{A,<:DiscreteSpace},
        properties...;
        kwargs...,
    ) where {A<:AbstractAgent}
    id = nextid(model)
    cnode = correct_pos_type(node, model)
    add_agent_pos!(A(id, cnode, properties...; kwargs...), model)
end

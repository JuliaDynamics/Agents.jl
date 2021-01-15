#=
This file implements functions shared by all discrete spaces.
Discrete spaces are by definition spaces with a finite amount of possible positions.

All these functions are granted "for free" to discrete spaces by simply extending:
- positions(model)
- ids_in_position(position, model)
=#

export positions,
    ids_in_position, agents_in_position, empty_positions, random_empty, has_empty_positions

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
    itr = reshape(n, length(n))
    if by == :random
        shuffle!(itr)
    elseif by == :population
        sort!(itr, by = i -> length(ids_in_position(i, model)), rev = true)
    else
        error("unknown `by`")
    end
    return itr
end

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

Return the agents in the position corresponding to `position` or position of `agent`.
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
    return any(i -> length(i) == 0, model.space.s)
end

"""
    random_empty(model::ABM{<:DiscreteSpace})
Return a random position without any agents, or `nothing` if no such positions exist.
"""
function random_empty(model::ABM{<:DiscreteSpace})
    empty = empty_positions(model)
    isempty(empty) && return nothing
    rand(collect(empty))
end

#######################################################################################
# Discrete space extra agent adding stuff
#######################################################################################
export add_agent_single!, fill_space!, move_agent_single!

"""
    add_agent_single!(agent, model::ABM{<:DiscreteSpace}) → agent

Add the `agent` to a random position in the space while respecting a maximum of one agent
per position. This function does nothing if there aren't any empty positions.
"""
function add_agent_single!(agent::A, model::ABM{<:DiscreteSpace,A}) where {A<:AbstractAgent}
    position = random_empty(model)
    isnothing(position) && return agent
    agent.pos = position
    add_agent_pos!(agent, model)
    return agent
end

"""
    add_agent_single!(model::ABM{<:DiscreteSpace}, properties...; kwargs...)
Same as `add_agent!(model, properties...)` but ensures that it adds an agent
into a position with no other agents (does nothing if no such position exists).
"""
function add_agent_single!(model::ABM{<:DiscreteSpace}, properties...; kwargs...)
    empty = collect(empty_positions(model))
    if length(empty) > 0
        add_agent!(rand(empty), model, properties...; kwargs...)
    end
end

"""
    fill_space!([A ,] model::ABM{<:DiscreteSpace,A}, args...; kwargs...)
    fill_space!([A ,] model::ABM{<:DiscreteSpace,A}, f::Function; kwargs...)
Add one agent to each position in the model's space. Similarly with [`add_agent!`](@ref),
the function creates the necessary agents and
the `args...; kwargs...` are propagated into agent creation.
If instead of `args...` a function `f` is provided, then `args = f(pos)` is the result of
applying `f` where `pos` is each position (tuple for grid, index for graph).

An optional first argument is an agent **type** to be created, and targets mixed agent
models where the agent constructor cannot be deduced (since it is a union).

## Example
```julia
using Agents
mutable struct Daisy <: AbstractAgent
    id::Int
    pos::Dims{2}
    breed::String
end
mutable struct Land <: AbstractAgent
    id::Int
    pos::Dims{2}
    temperature::Float64
end
space = GridSpace((10, 10))
model = ABM(Union{Daisy, Land}, space)
temperature(pos) = (pos[1]/10, ) # must be Tuple!
fill_space!(Land, model, temperature)
```
"""
fill_space!(model::ABM{S,A}, args...; kwargs...) where {S,A<:AbstractAgent} =
    fill_space!(A, model, args...; kwargs...)

function fill_space!(
    ::Type{A},
    model::ABM{<:DiscreteSpace,U},
    args...;
    kwargs...,
) where {A<:AbstractAgent,U<:AbstractAgent}
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
    move_agent_single!(agent, model::ABM{<:DiscreteSpace}) → agentt

Move agent to a random position while respecting a maximum of one agent
per position. If there are no empty positions, the agent won't move.
"""
function move_agent_single!(
    agent::A,
    model::ABM{<:DiscreteSpace,A},
) where {A<:AbstractAgent}
    empty = collect(empty_positions(model))
    if length(empty) > 0
        move_agent!(agent, rand(empty), model)
    end
    return agent
end

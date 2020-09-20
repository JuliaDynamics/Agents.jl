#=
This file implements functions shared by all discrete spaces.
Discrete spaces are by definition spaces with a finite amount of possible positions.

All these functions are granted "for free" to discrete spaces by simply extending:
- nodes(model)
- agents_in_pos(position, model)
=#

export nodes, agents_in_pos, empty_positions, random_empty, has_empty_positions

"""
    nodes(model::ABM{A, <:DiscreteSpace}) → ns
Return an iterator over all positions of a model with a discrete space (called nodes).

    nodes(model::ABM{A, <:DiscreteSpace}, by::Symbol) → ns
Return all positions of a model with a discrete space (called nodes), sorting them
using the argument `by` which can be:
* `:random` - randomly sorted
* `:population` - positions are sorted depending on how many agents they accommodate.
  The more populated positions are first.
"""
function nodes(model::ABM{<:AbstractAgent,<:DiscreteSpace}, by::Symbol)
    n = collect(nodes(model))
    itr = reshape(n, length(n))
    if by == :random
        shuffle!(itr)
    elseif by == :population
        sort!(itr, by = i -> length(agents_in_pos(i, model)), rev = true)
    else
        error("unknown `by`")
    end
    return itr
end

# TODO: Does this really have to be collecting...?
function empty_positions(model::ABM{<:AbstractAgent,<:DiscreteSpace})
    collect(Iterators.filter(i -> length(agents_in_pos(i, model)) == 0, nodes(model)))
end

"""
    isempty(position, model::ABM{A, <:DiscreteSpace})
Return `true` if there are no agents in `position`.
"""
Base.isempty(pos, model::ABM) = isempty(agents_in_pos(pos, model))


"""
    has_empty_positions(model::ABM{A, <:DiscreteSpace})
Return `true` if there are any positions in the model without agents.
"""
function has_empty_positions(model::ABM{<:AbstractAgent,<:DiscreteSpace})
    return any(i -> length(i) == 0, model.space.s)
end

"""
    random_empty(model::ABM{A, <:DiscreteSpace})
Return a random position without any agents, or `nothing` if no such positions exist.
"""
function random_empty(model::ABM{<:AbstractAgent,<:DiscreteSpace})
    empty = empty_positions(model)
    isempty(empty) && return nothing
    rand(empty)
end

#######################################################################################
# Discrete space extra agent adding stuff
#######################################################################################
export add_agent_single!, fill_space!, move_agent_single!

"""
    add_agent_single!(agent::A, model::ABM{A, <: DiscreteSpace}) → agent

Add the `agent` to a random position in the space while respecting a maximum of one agent
per node position. This function does nothing if there aren't any empty positions.
"""
function add_agent_single!(agent::A, model::ABM{A,<:DiscreteSpace}) where {A<:AbstractAgent}
    position = random_empty(model)
    isnothing(position) && return agent
    agent.pos = position
    add_agent_pos!(agent, model)
    return agent
end

"""
    add_agent_single!(model::ABM{A, <: DiscreteSpace}, properties...; kwargs...)
Same as `add_agent!(model, properties...)` but ensures that it adds an agent
into a position with no other agents (does nothing if no such position exists).
"""
function add_agent_single!(
    model::ABM{A,<:DiscreteSpace},
    properties...;
    kwargs...,
) where {A<:AbstractAgent}
    empty = empty_positions(model)
    if length(empty) > 0
        add_agent!(rand(empty), model, properties...; kwargs...)
    end
end

"""
    fill_space!([A ,] model::ABM{A, <:DiscreteSpace}, args...; kwargs...)
    fill_space!([A ,] model::ABM{A, <:DiscreteSpace}, f::Function; kwargs...)
Add one agent to each node in the model's space. Similarly with [`add_agent!`](@ref),
the function creates the necessary agents and
the `args...; kwargs...` are propagated into agent creation.
If instead of `args...` a function `f` is provided, then `args = f(pos)` is the result of
applying `f` where `pos` is each position (tuple for grid, node index for graph).

An optional first argument is an agent **type** to be created, and targets mixed agent
models where the agent constructor cannot be deduced (since it is a union).

## Example
```julia
using Agents
mutable struct Daisy <: AbstractAgent
    id::Int
    pos::Tuple{Int, Int}
    breed::String
end
mutable struct Land <: AbstractAgent
    id::Int
    pos::Tuple{Int, Int}
    temperature::Float64
end
space = GridSpace((10, 10), moore = true, periodic = true)
model = ABM(Union{Daisy, Land}, space)
temperature(pos) = (pos[1]/10, ) # must be Tuple!
fill_space!(Land, model, temperature)
```
"""
fill_space!(model::ABM{A}, args...; kwargs...) where {A<:AbstractAgent} =
    fill_space!(A, model, args...; kwargs...)

function fill_space!(
    ::Type{A},
    model::ABM{U,<:DiscreteSpace},
    args...;
    kwargs...,
) where {A<:AbstractAgent,U<:AbstractAgent}
    for n in nodes(model)
        id = nextid(model)
        add_agent_pos!(A(id, n, args...; kwargs...), model)
    end
    return model
end

function fill_space!(
    ::Type{A},
    model::ABM{U,<:DiscreteSpace},
    f::Function;
    kwargs...,
) where {A<:AbstractAgent,U<:AbstractAgent}
    for n in nodes(model)
        id = nextid(model)
        args = f(n)
        add_agent_pos!(A(id, n, args...; kwargs...), model)
    end
    return model
end

"""
    move_agent_single!(agent::A, model::ABM{A, <:DiscreteSpace}) → agentt

Move agent to a random position while respecting a maximum of one agent
per position. If there are no empty positions, the agent won't move.
"""
function move_agent_single!(
        agent::A,
        model::ABM{A,<:DiscreteSpace},
    ) where {A<:AbstractAgent}
    empty = empty_positions(model)
    if length(empty) > 0
        move_agent!(agent, rand(empty), model)
    end
    return agent
end

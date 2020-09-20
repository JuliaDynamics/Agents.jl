#=
This file implements functions shared by all discrete spaces.
Discrete spaces are by definition spaces with a finite amount of possible positions.

All these functions are granted "for free" to discrete spaces by simply extending:
- nodes(model)
- get_node_contents(position, model)
=#

export nodes, get_node_contents, find_empty_nodes, pick_empty, has_empty_nodes

"""
    nodes(model::ABM{A, <:DiscreteSpace}) → ns
Return an iterator over all positions of a model with a discrete space (called nodes).

    nodes(model::ABM{A, <:DiscreteSpace}, by::Symbol) → ns
Return all positions of a model with a discrete space (called nodes), sorting them
using the argument `by` which can be:
* `:random` - randomly sorted
* `:population` - nodes are sorted depending on how many agents they accommodate.
  The more populated nodes are first.
"""
function nodes(model::ABM{<:AbstractAgent,<:DiscreteSpace}, by::Symbol)
    n = collect(nodes(model))
    itr = reshape(n, length(n))
    if by == :random
        shuffle!(itr)
    elseif by == :population
        sort!(itr, by = i -> length(get_node_contents(i, model)), rev = true)
    else
        error("unknown `by`")
    end
    return itr
end

# TODO: Does this really have to be collecting...?
function find_empty_nodes(model::ABM{<:AbstractAgent,<:DiscreteSpace})
    collect(Iterators.filter(i -> length(get_node_contents(i, model)) == 0, nodes(model)))
end

"""
    isempty(position, model::ABM{A, <:DiscreteSpace})
Return `true` if there are no agents in `node`.
"""
Base.isempty(pos, model::ABM) = isempty(get_node_contents(pos, model))


"""
    has_empty_nodes(model::ABM{A, <:DiscreteSpace})
Return `true` if there are any positions in the model without agents.
"""
function has_empty_nodes(model::ABM{<:AbstractAgent,<:DiscreteSpace})
    s = model.space.s
    return any(i -> length(i) == 0, s)
end

"""
    pick_empty(model::ABM{A, <:DiscreteSpace})
Return a random position without any agents, or `nothing` if no such positions exist.
"""
function pick_empty(model::ABM{<:AbstractAgent,<:DiscreteSpace})
    empty_nodes = find_empty_nodes(model)
    isempty(empty_nodes) && return nothing
    rand(empty_nodes)
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
    node = pick_empty(model)
    isnothing(node) && return agent
    agent.pos = node
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
    empty_positions = find_empty_nodes(model)
    if length(empty_positions) > 0
        add_agent!(rand(empty_positions), model, properties...; kwargs...)
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

Move agent to a random node while respecting a maximum of one agent
per node. If there are no empty nodes, the agent won't move.
"""
function move_agent_single!(
        agent::A,
        model::ABM{A,<:DiscreteSpace},
    ) where {A<:AbstractAgent}
    empty_positions = find_empty_nodes(model)
    if length(empty_positions) > 0
        random_node = rand(empty_positions)
        move_agent!(agent, random_node, model)
    end
    return agent
end

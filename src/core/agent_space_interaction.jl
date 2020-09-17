#=
This file establishes the agent-space interaction API.
=#
export move_agent!,
    add_agent!,
    add_agent_single!,
    add_agent_pos!,
    move_agent_single!,
    kill_agent!,
    genocide!,
    nextid,
    fill_space!

#######################################################################################
# Killing agents
#######################################################################################
"""
    kill_agent!(agent::AbstractAgent, model::ABM)

Remove an agent from model, and from the space if the model has a space.
"""
function kill_agent!(agent::A, model::ABM{A,<:DiscreteSpace}) where {A<:AbstractAgent}
    agentnode = coord2vertex(agent.pos, model)
    # remove from the space
    splice!(
        agent_positions(model)[agentnode],
        findfirst(a -> a == agent.id, agent_positions(model)[agentnode]),
    )
    delete!(model.agents, agent.id)
    return model
end

function kill_agent!(agent::A, model::ABM{A,Nothing}) where {A<:AbstractAgent}
    delete!(model.agents, agent.id)
end

kill_agent!(id::Integer, model) = kill_agent!(model[id], model)


"""
    genocide!(model::ABM)
Kill all the agents of the model.
"""
genocide!(model::ABM{A,<:Union{DiscreteSpace,Nothing}}) where {A} =
    for a in allagents(model)
        kill_agent!(a, model)
    end


"""
    genocide!(model::ABM, n::Int)
Kill the agents of the model whose IDs are larger than n.
"""
genocide!(model::ABM{A,<:Union{DiscreteSpace,Nothing}}, n::Integer) where {A} =
    for (k, v) in model.agents
        k > n && kill_agent!(v, model)
    end

"""
    genocide!(model::ABM, f::Function)
Kill all agents where the function `f(agent)` returns `true`.
"""
genocide!(model::ABM{A,<:Union{DiscreteSpace,Nothing}}, f::Function) where {A} =
    for a in allagents(model)
        f(a) && kill_agent!(a, model)
    end

#######################################################################################
# Moving agents
#######################################################################################
"""
    move_agent!(agent::A [, pos], model::ABM{A, <: DiscreteSpace}) → agent

Move agent to the given position, or to a random one if a position is not given.
`pos` must be the appropriate position type depending on the space type.
"""
function move_agent!(
        agent::A,
        pos::NTuple{D,Integer},
        model::ABM{A,<:DiscreteSpace},
    ) where {A<:AbstractAgent,D}
    @assert isa(pos, typeof(agent.pos)) "Invalid dimension for `pos`"
    nodenumber = coord2vertex(pos, model)
    move_agent!(agent, nodenumber, model)
end

function move_agent!(agent::AbstractAgent, pos::Integer, model::ABM)
    # remove agent from old position
    if typeof(agent.pos) <: Tuple
        oldnode = coord2vertex(agent.pos, model)
        splice!(
            model.space.agent_positions[oldnode],
            findfirst(a -> a == agent.id, model.space.agent_positions[oldnode]),
        )
        agent.pos = vertex2coord(pos, model)  # update agent position
    else
        splice!(
            model.space.agent_positions[agent.pos],
            findfirst(a -> a == agent.id, model.space.agent_positions[agent.pos]),
        )
        agent.pos = pos
    end
    push!(model.space.agent_positions[pos], agent.id)
    return agent
end

function move_agent!(agent::AbstractAgent, model::ABM)
    nodenumber = rand(1:nv(model.space))
    move_agent!(agent, nodenumber, model)
    return agent
end

"""
    move_agent_single!(agent::AbstractAgent, model::ABM) → agent

Move agent to a random node while respecting a maximum of one agent
per node. If there are no empty nodes, the agent wont move.
Only valid for non-continuous spaces.
"""
function move_agent_single!(agent::AbstractAgent, model::ABM)
    empty_cells = find_empty_nodes(model)
    if length(empty_cells) > 0
        random_node = rand(empty_cells)
        move_agent!(agent, random_node, model)
    end
    return agent
end

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

function add_agent_pos!(agent::A, model::ABM{A,Nothing}) where {A<:AbstractAgent}
    model[agent.id] = agent
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

function add_agent!(agent::A, model::ABM{A,Nothing}) where {A<:AbstractAgent}
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
        model::ABM{A,Nothing},
        properties...;
        kwargs...,
    ) where {A<:AbstractAgent}
    add_agent_pos!(A(nextid(model), properties...; kwargs...), model)
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

"""
    nextid(model::ABM) → id
Return a valid `id` for creating a new agent with it.
"""
nextid(model::ABM) = isempty(model.agents) ? 1 : maximum(keys(model.agents)) + 1

"""
    add_agent_single!(agent::A, model::ABM{A, <: DiscreteSpace}) → agent

Add agent to a random node in the space while respecting a maximum one agent per node.
This function throws a warning if no empty nodes remain.
"""
function add_agent_single!(agent::A, model::ABM{A,<:DiscreteSpace}) where {A<:AbstractAgent}
    empty_cells = find_empty_nodes(model)
    if length(empty_cells) > 0
        agent.pos = correct_pos_type(rand(empty_cells), model)
        add_agent_pos!(agent, model)
    else
        @warn "No empty nodes found for `add_agent_single!`."
    end
end

"""
    add_agent_single!(model::ABM{A, <: DiscreteSpace}, properties...; kwargs...)
Same as `add_agent!(model, properties...)` but ensures that it adds an agent
into a node with no other agents (does nothing if no such node exists).
"""
function add_agent_single!(
        model::ABM{A,<:DiscreteSpace},
        properties...;
        kwargs...,
    ) where {A<:AbstractAgent}
    empty_cells = find_empty_nodes(model)
    if length(empty_cells) > 0
        add_agent!(rand(empty_cells), model, properties...; kwargs...)
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

An optional first argument is an agent **type** to be created, and targets mixed-agent
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
temperature(pos) = (pos[1]/10, ) # make it Tuple!
fill_space!(Land, model, temperature)
```
"""
fill_space!(model::ABM{A}, args...; kwargs...) where {A<:AbstractAgent} =
fill_space!(A, model, args...; kwargs...)

function fill_space!(::Type{A}, model::ABM, args...; kwargs...) where {A<:AbstractAgent}
    for n in nodes(model)
        id = nextid(model)
        cnode = correct_pos_type(n, model)
        add_agent_pos!(A(id, cnode, args...; kwargs...), model)
    end
    return model
end

function fill_space!(::Type{A}, model::ABM, f::Function; kwargs...) where {A<:AbstractAgent}
    for n in nodes(model)
        id = nextid(model)
        cnode = correct_pos_type(n, model)
        args = f(cnode)
        add_agent_pos!(A(id, cnode, args...; kwargs...), model)
    end
    return model
end

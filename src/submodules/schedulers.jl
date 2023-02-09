export schedule, Schedulers
"""
    schedule(model) → ids
Return an iterator over the scheduled IDs using the model's scheduler.
Literally equivalent with `model.scheduler(model)`.
"""
schedule(model::ABM) = model.scheduler(model)

# Notice how the above lines are *outside* the submodule

"""
    Schedulers
Submodule containing all predefined schedulers of Agents.jl and the scheduling API.
Schedulers have a very simple interface. They are functions that take as an input the ABM and
return an iterator over agent IDs. Notice that this iterator can be a "true" iterator
(non-allocated) or can be just a standard vector of IDs. You can define your own scheduler
according to this API and use it when making an [`AgentBasedModel`](@ref).
You can also use the function `schedule(model)` to obtain the scheduled ID list,
if you prefer to write your own `step!`-like loop.

See also [Advanced scheduling](@ref) for making more advanced schedulers.

Notice that schedulers can be given directly to model creation, and thus become the
"default" scheduler a model uses, but they can just as easily be incorporated in a
`model_step!` function as shown in [Advanced stepping](@ref).
"""
module Schedulers
using Agents
using Random: shuffle!, randsubseq, randsubseq!

export Randomly, by_id, fastest, Partially, ByProperty, ByType

####################################
# Schedulers
####################################

function get_ids!(ids::Vector{Int}, model::ABM)
    resize!(ids, nagents(model))
    for (i, id) in enumerate(allids(model))
        ids[i] = id
    end
end

"""
    Schedulers.fastest
A scheduler that activates all agents once per step in the order dictated by the
agent's container, which is arbitrary (the keys sequence of a dictionary).
This is the fastest way to activate all agents once per step.
"""
fastest(model::ABM) = allids(model)

"""
    Schedulers.by_id
A scheduler that activates all agents agents at each step according to their id.
"""
function by_id(model::ABM)
    agent_ids = sort(collect(allids(model)))
    return agent_ids
end

struct ByID
    ids::Vector{Int}
end

"""
    Schedulers.ByID()
A non-allocating scheduler that activates all agents agents at each step according to their id.
"""
ByID() = ByID(Int[])

function (sched::ByID)(model::ABM)
    get_ids!(sched.ids, model)
    sort!(sched.ids)
end

"""
    Schedulers.randomly
A scheduler that activates all agents once per step in a random order.
Different random ordering is used at each different step.
"""
function randomly(model::ABM)
    order = shuffle!(model.rng, collect(allids(model)))
end

struct Randomly
    ids::Vector{Int}
end

"""
    Schedulers.Randomly()
A non-allocating scheduler that activates all agents once per step in a random order.
Different random ordering is used at each different step.
"""
Randomly() = Randomly(Int[])
function (sched::Randomly)(model::ABM)
    get_ids!(sched.ids, model)
    shuffle!(model.rng, sched.ids)
end

"""
    Schedulers.partially(p)
A scheduler that at each step activates only `p` percentage of randomly chosen agents.
"""
function partially(p::Real)
    function partial(model::ABM)
        ids = collect(allids(model))
        return randsubseq(model.rng, ids, p)
    end
    return partial
end

struct Partially{R<:Real}
    p::R
    all_ids::Vector{Int}
    schedule::Vector{Int}
end

"""
    Schedulers.Partially(p)
A non-allocating scheduler that at each step activates only `p` percentage of randomly
chosen agents.
"""
Partially(p::R) where {R<:Real} = Partially{R}(p, Int[], Int[])

function (sched::Partially)(model::ABM)
    get_ids!(sched.all_ids, model)
    randsubseq!(model.rng, sched.schedule, sched.all_ids, sched.p)
end

"""
    Schedulers.by_property(property)
A scheduler that at each step activates the agents in an order dictated by their `property`,
with agents with greater `property` acting first. `property` can be a `Symbol`, which
just dictates which field of the agents to compare, or a function which inputs an agent
and outputs a real number.
"""
function by_property(p)
    function property(model::ABM)
        ids = collect(allids(model))
        properties = [Agents.get_data(model[id], p) for id in ids]
        s = sortperm(properties)
        return ids[s]
    end
end

struct ByProperty{P}
    p::P
    properties::Vector{Float64} # TODO: don't assume Float64
    ids::Vector{Int}
    perm::Vector{Int}
end

"""
    Schedulers.ByProperty(property)
A non-allocating scheduler that at each step activates the agents in an order dictated by
their `property`, with agents with greater `property` acting first. `property` can be a
`Symbol`, which just dictates which field of the agents to compare, or a function which
inputs an agent and outputs a real number.
"""
ByProperty(p::P) where {P} = ByProperty{P}(p, Float64[], Int[], Int[])

function (sched::ByProperty)(model::ABM)
    get_ids!(sched.ids, model)
    resize!(sched.properties, length(sched.ids))

    for (i, id) in enumerate(sched.ids)
        sched.properties[i] = Agents.get_data(model[id], sched.p)
    end

    initialized = true
    if length(sched.perm) != length(sched.ids)
        resize!(sched.perm, length(sched.ids))
        initialized = false
    end

    sortperm!(sched.perm, sched.properties; initialized)
    return Iterators.map(i -> sched.ids[i], sched.perm)
end

"""
    Schedulers.by_type(shuffle_types::Bool, shuffle_agents::Bool)
A scheduler useful only for mixed agent models using `Union` types.
- Setting `shuffle_types = true` groups by agent type, but randomizes the type order.
Otherwise returns agents grouped in order of appearance in the `Union`.
- `shuffle_agents = true` randomizes the order of agents within each group, `false` returns
the default order of the container (equivalent to [`Schedulers.fastest`](@ref)).
"""
function by_type(shuffle_types::Bool, shuffle_agents::Bool)
    function by_union(model::ABM{S,A}) where {S,A}
        types = Agents.union_types(A)
        sets = [Integer[] for _ in types]
        for agent in allagents(model)
            idx = findfirst(t -> t == typeof(agent), types)
            push!(sets[idx], agent.id)
        end
        shuffle_types && shuffle!(model.rng, sets)
        if shuffle_agents
            for set in sets
                shuffle!(model.rng, set)
            end
        end
        vcat(sets...)
    end
end

"""
    Schedulers.by_type((C, B, A), shuffle_agents::Bool)
A scheduler that activates agents by type in specified order (since `Union`s are not order
preserving). `shuffle_agents = true` randomizes the order of agents within each group.
"""
function by_type(order::Tuple{Type,Vararg{Type}}, shuffle_agents::Bool)
    function by_ordered_union(model::ABM{S,A}) where {S,A}
        types = Agents.union_types(A)
        if order !== nothing
            @assert length(types) == length(order) "Invalid dimension for `order`"
            types = order
        end
        sets = [Integer[] for _ in types]
        for agent in allagents(model)
            idx = findfirst(t -> t == typeof(agent), types)
            push!(sets[idx], agent.id)
        end
        if shuffle_agents
            for set in sets
                shuffle!(model.rng, set)
            end
        end
        vcat(sets...)
    end
end

struct ByType
    shuffle_types::Bool
    shuffle_agents::Bool
    type_inds::Dict{DataType,Int}
    ids::Vector{Vector{Int}}
end

"""
    Schedulers.ByType(shuffle_types::Bool, shuffle_agents::Bool, agent_union)
A non-allocating scheduler useful only for mixed agent models using `Union` types.
- Setting `shuffle_types = true` groups by agent type, but randomizes the type order.
Otherwise returns agents grouped in order of appearance in the `Union`.
- `shuffle_agents = true` randomizes the order of agents within each group, `false` returns
the default order of the container (equivalent to [`Schedulers.fastest`](@ref)).
- `agent_union` is a `Union` of all valid agent types (as passed to [`ABM`](@ref))
"""
function ByType(shuffle_types::Bool, shuffle_agents::Bool, agent_union)
    types = Agents.union_types(agent_union)
    return ByType(
        shuffle_types,
        shuffle_agents,
        Dict(t => i for (i, t) in enumerate(types)),
        [Int[] for _ in 1:length(types)]
    )
end

"""
    Schedulers.ByType((C, B, A), shuffle_agents::Bool)
A non-allocating scheduler that activates agents by type in specified order (since
`Union`s are not order preserving). `shuffle_agents = true` randomizes the order of
agents within each group.
"""
function ByType(order::Tuple{Type,Vararg{Type}}, shuffle_agents::Bool)
    return ByType(
        false,
        shuffle_agents,
        Dict(t => i for (i, t) in enumerate(order)),
        [Int[] for _ in 1:length(order)]
    )
end

function (sched::ByType)(model::ABM)
    for i in 1:length(sched.ids)
        empty!(sched.ids[i])
    end

    for agent in allagents(model)
        push!(sched.ids[sched.type_inds[typeof(agent)]], agent.id)
    end
    
    sched.shuffle_types && shuffle!(model.rng, sched.ids)

    if sched.shuffle_agents
        for i in 1:length(sched.ids)
            shuffle!(model.rng, sched.ids[i])
        end
    end

    return Iterators.flatten(it for it in sched.ids)
end

@deprecate by_id ById
@deprecate randomly Randomly
@deprecate partially Partially
@deprecate by_property ByProperty
@deprecate by_type ByType

end # Schedulers submodule

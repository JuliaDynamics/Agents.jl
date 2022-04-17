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
using Random: shuffle!, randsubseq!

export randomly, by_id, fastest, partially, by_property, by_type

####################################
# Schedulers
####################################

function get_ids!(ids::Vector{Int}, model::ABM)
    resize!(ids, nagents(model))
    for (i, id) in enumerate(keys(model.agents))
        ids[i] = id
    end
end

"""
    Schedulers.fastest
A scheduler that activates all agents once per step in the order dictated by the
agent's container, which is arbitrary (the keys sequence of a dictionary).
This is the fastest way to activate all agents once per step.
"""
fastest(model::ABM) = keys(model.agents)

"""
    Schedulers.by_id
A scheduler that activates all agents agents at each step according to their id.
"""
struct by_id
    ids::Vector{Int}
end

by_id() = by_id(Int[])

function (sched::by_id)(model::ABM)
    get_ids!(sched.ids, model)
    sort!(sched.ids)
end

"""
    Schedulers.randomly
A scheduler that activates all agents once per step in a random order.
Different random ordering is used at each different step.
"""
struct randomly
    ids::Vector{Int}
end

randomly() = randomly(Int[])
function (sched::randomly)(model::ABM)
    get_ids!(sched.ids, model)
    shuffle!(model.rng, sched.ids)
end

"""
    Schedulers.partially(p)
A scheduler that at each step activates only `p` percentage of randomly chosen agents.
"""
struct partially{R<:Real}
    p::R
    all_ids::Vector{Int}
    schedule::Vector{Int}
end

partially(p::R) where {R<:Real} = partially{R}(p, Int[], Int[])

function (sched::partially)(model::ABM)
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
struct by_property{P}
    p::P
    properties::Vector{Float64} # TODO: don't assume Float64
    ids::Vector{Int}
    perm::Vector{Int}
end

by_property(p::P) where {P} = by_property{P}(p, Float64[], Int[], Int[])

function (sched::by_property)(model::ABM)
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



struct by_type
    shuffle_types::Bool
    shuffle_agents::Bool
    type_inds::Dict{DataType,Int}
    ids::Vector{Vector{Int}}
end

"""
    Schedulers.by_type(shuffle_types::Bool, shuffle_agents::Bool, agent_union)
A scheduler useful only for mixed agent models using `Union` types (`agent_union`).
- Setting `shuffle_types = true` groups by agent type, but randomizes the type order.
Otherwise returns agents grouped in order of appearance in the `Union`.
- `shuffle_agents = true` randomizes the order of agents within each group, `false` returns
the default order of the container (equivalent to [`Schedulers.fastest`](@ref)).
"""
function by_type(shuffle_types::Bool, shuffle_agents::Bool, agent_union)
    types = Agents.union_types(agent_union)
    return by_type(
        shuffle_types,
        shuffle_agents,
        Dict(t => i for (i, t) in enumerate(types)),
        [Int[] for _ in 1:length(types)]
    )
end

"""
    Schedulers.by_type((C, B, A), shuffle_agents::Bool)
A scheduler that activates agents by type in specified order (since `Union`s are not order
preserving). `shuffle_agents = true` randomizes the order of agents within each group.
"""
function by_type(order::Tuple{Type,Vararg{Type}}, shuffle_agents::Bool)
    return by_type(
        false,
        shuffle_agents,
        Dict(t => i for (i, t) in enumerate(order)),
        [Int[] for _ in 1:length(order)]
    )
end

function (sched::by_type)(model::ABM)
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

end # Schedulers submodule

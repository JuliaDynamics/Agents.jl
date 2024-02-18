export schedule, Schedulers

"""
    schedule(model::StandardABM) → ids

Return an iterator over the scheduled IDs using the model's default scheduler.
"""
schedule(model::ABM) = abmscheduler(model)(model)

schedule(model::ABM, scheduler) = Iterators.filter(id -> id in allids(model), scheduler(model))
schedule(model::Agents.VecABM, scheduler) = scheduler(model)

# Notice how the above lines are *outside* the submodule

"""
    Schedulers

Submodule containing all predefined schedulers of Agents.jl that can be used with
[`StandardABM`](@ref).

Schedulers have a very simple interface. They are functions that take as an input the ABM and
return an iterator over agent IDs: `f(model) -> iterator`.
Notice that this iterator can be non-allocated specialized
type or just a standard vector of IDs.

Schedulers have many purposes:

1. Can be given in [`StandardABM`](@ref) as a default scheduler.
   This functionality is only meaningful when the `agent_step!` has been configured.
   The function `schedule(model)` will return the scheduled IDs.
2. Can be used by a user when performing [manual scheduling](@ref manual_scheduling)
   in case `agent_step!` has not been configured.
3. Can be used to globally filter agents by type/property/whatever. For example,
   one can use the [`ByProperty`](@ref) scheduler to simply obtain
   the list of all agent IDs that satisfy a particular property.

See also [Advanced scheduling](@ref) for making more advanced schedulers.
"""
module Schedulers
using Agents
using Random: shuffle!, randsubseq, randsubseq!

export fastest, Randomly, ByID, Partially, ByProperty, ByType

####################################
# Schedulers
####################################

function get_ids!(ids::Vector{Int}, model::ABM)
    resize!(ids, nagents(model))
    for (i, id) in enumerate(allids(model))
        ids[i] = id
    end
end

function get_ids!(ids::Vector{Int}, model::Agents.VecABM)
    n_sched = length(ids)
    nagents(model) == n_sched && return nothing
    resize!(ids, nagents(model))
    ids[n_sched+1:end] = allids(model)[n_sched+1:end]
end

"""
    Schedulers.fastest

A scheduler that orders all agent IDs in the fastest way possible,
which is the default order dictaed by the agent container.
"""
fastest(model::ABM) = allids(model)

"""
    Schedulers.ByID()

A scheduler that orders all agent IDs by their integer value.
"""
struct ByID
    ids::Vector{Int}
end

ByID() = ByID(Int[])

function (sched::ByID)(model::ABM)
    get_ids!(sched.ids, model)
    sort!(sched.ids)
end

(sched::ByID)(model::Agents.VecABM) = allids(model)

"""
    Schedulers.Randomly()

A scheduler that randomly orders all agent IDs.
Different random ordering is used at each different step.
"""
struct Randomly
    ids::Vector{Int}
end

Randomly() = Randomly(Int[])
function (sched::Randomly)(model::ABM)
    get_ids!(sched.ids, model)
    shuffle!(abmrng(model), sched.ids)
end

"""
    Schedulers.Partially(p)

A scheduler that orders only `p` percentage of randomly chosen agent IDs.
"""
struct Partially{R<:Real}
    p::R
    all_ids::Vector{Int}
    schedule::Vector{Int}
end

Partially(p::R) where {R<:Real} = Partially{R}(p, Int[], Int[])

function (sched::Partially)(model::ABM)
    get_ids!(sched.all_ids, model)
    randsubseq!(abmrng(model), sched.schedule, sched.all_ids, sched.p)
end

"""
    Schedulers.ByProperty(property)

A scheduler that orders agent IDs by their `property`, with agents with greater `property`
being ordered first. `property` can be a
`Symbol`, which just dictates which field of the agents to compare, or a function which
inputs an agent and outputs a real number.
"""
struct ByProperty{P}
    p::P
    ids::Vector{Int}
    perm::Vector{Int}
end

ByProperty(p::P) where {P} = ByProperty{P}(p, Int[], Int[])

function (sched::ByProperty)(model::ABM)
    get_ids!(sched.ids, model)

    properties = [Agents.get_data(model[id], sched.p) for id in sched.ids]

    initialized = true
    if length(sched.perm) != length(sched.ids)
        resize!(sched.perm, length(sched.ids))
        initialized = false
    end

    sortperm!(sched.perm, properties; initialized)
    return Iterators.map(i -> sched.ids[i], sched.perm)
end

"""
    Schedulers.ByType(shuffle_types::Bool, shuffle_agents::Bool, agent_union)

A scheduler useful only for mixed agent models using `Union` types.
- Setting `shuffle_types = true` groups by agent type, but randomizes the type order.
  Otherwise returns agent IDs grouped in order of appearance in the `Union`.
- `shuffle_agents = true` randomizes the order of agents within each group, `false` returns
  the default order of the container (equivalent to [`Schedulers.fastest`](@ref)).
- `agent_union` is a `Union` of all valid agent types (as passed to [`ABM`](@ref))


    Schedulers.ByType((C, B, A), shuffle_agents::Bool)

A scheduler that orders agent IDs by type in specified order (since
`Union`s are not order preserving). `shuffle_agents = true` randomizes the order of
agents within each group.
"""
struct ByType
    shuffle_types::Bool
    shuffle_agents::Bool
    type_inds::Dict{DataType,Int}
    ids::Vector{Vector{Int}}
end

function ByType(shuffle_types::Bool, shuffle_agents::Bool, agent_union)
    types = Agents.union_types(agent_union)
    return ByType(
        shuffle_types,
        shuffle_agents,
        Dict(t => i for (i, t) in enumerate(types)),
        [Int[] for _ in 1:length(types)]
    )
end

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

    sched.shuffle_types && shuffle!(abmrng(model), sched.ids)

    if sched.shuffle_agents
        for i in 1:length(sched.ids)
            shuffle!(abmrng(model), sched.ids[i])
        end
    end

    return Iterators.flatten(it for it in sched.ids)
end

end # Schedulers submodule

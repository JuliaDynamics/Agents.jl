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
using Random: shuffle!, randsubseq

export AbstractScheduler,
    Fastest,
    ByID,
    Randomly,
    Partially,
    ByProperty,
    ByType

abstract type AbstractScheduler end

####################################
# Schedulers
####################################
"""
    Schedulers.Fastest
A scheduler that activates all agents once per step in the order dictated by the
agent's container, which is arbitrary (the keys sequence of a dictionary).
This is the fastest way to activate all agents once per step.
"""
struct Fastest <: AbstractScheduler end
(::Fastest)(model::ABM) = keys(model.agents)

"""
    Schedulers.ByID
A scheduler that activates all agents agents at each step according to their id.
"""
struct ByID <: AbstractScheduler end
(::ByID)(model::ABM) = sort(collect(keys(model.agents)))

"""
    Schedulers.Randomly
A scheduler that activates all agents once per step in a random order.
Different random ordering is used at each different step.
"""
struct Randomly <: AbstractScheduler end
(::Randomly)(model::ABM) = shuffle!(model.rng, collect(keys(model.agents)))

"""
    Schedulers.Partially(p::Float64)
A scheduler that at each step activates only `p` percentage of randomly chosen agents.
"""
struct Partially <: AbstractScheduler
    p::Float64
end
(sched::Partially)(model::ABM) = randsubseq(model.rng, collect(keys(model.agents)), sched.p)


"""
    Schedulers.ByProperty(property)
A scheduler that at each step activates the agents in an order dictated by their `property`,
with agents with greater `property` acting first. `property` can be a `Symbol`, which
just dictates which field of the agents to compare, or a function which inputs an agent
and outputs a real number.
"""
struct ByProperty{T<:Union{Symbol,Function}} <: AbstractScheduler
    property::T
end

function (sched::P)(model::ABM) where {P<:ByProperty}
    ids = collect(keys(model.agents))
    properties = [Agents.get_data(model[id], sched.property) for id in ids]
    s = sortperm(properties)
    return ids[s]
end

struct ByType <: AbstractScheduler
    types::Tuple{DataType,Vararg{DataType}}
    shuffle_types::Bool
    shuffle_agents::Bool
end

"""
    Schedulers.ByType(types::Union{<:AbstractAgent}, shuffle_types::Bool, shuffle_agents::Bool)
A scheduler useful only for mixed agent models using `Union` types.
- Setting `shuffle_types = true` groups by agent type, but randomizes the type order.
Otherwise returns agents grouped in order of appearance in the `Union`.
- `shuffle_agents = true` randomizes the order of agents within each group, `false` returns
the default order of the container (equivalent to [`Schedulers.Fastest`](@ref)).
"""
ByType(::T, shuffle_types::Bool, shuffle_agents::Bool) where {T<:Union{<:AbstractAgent}} =
    ByType(union_types(T), shuffle_types, shuffle_agents)
"""
    Schedulers.ByType((C, B, A), shuffle_agents::Bool)
A scheduler that activates agents by type in specified order (since `Union`s are not order
preserving). `shuffle_agents = true` randomizes the order of agents within each group.
"""
ByType(t::Tuple{DataType,Vararg{DataType}}, shuffle_agents::Bool) =
    ByType(t, false, shuffle_agents)

function (sched::ByType)(model::ABM{S,A}) where {S,A}
    sets = [Integer[] for _ in sched.types]
    for agent in allagents(model)
        idx = findfirst(t -> agent isa t, sched.types)
        push!(sets[idx], agent.id)
    end
    sched.shuffle_types && shuffle!(model.rng, sets)
    if sched.shuffle_agents
        for set in sets
            shuffle!(model.rng, set)
        end
    end
    Iterators.flatten(zip(sets...))
end

end # Schedulers submodule

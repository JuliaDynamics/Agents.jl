export schedule, Schedulers
"""
    schedule(model) → ids
Return an iterator over the scheduled IDs using the model's scheduler.
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

export Schedulers.randomly, Schedulers.by_id, Schedulers.fastest, Schedulers.partially, Schedulers.by_property, Schedulers.by_type

####################################
# Schedulers
####################################
"""
    Schedulers.fastest
A scheduler that activates all agents once per step in the order dictated by the
agent's container, which is arbitrary (the keys sequence of a dictionary).
This is the fastest way to activate all agents once per step.
"""
Schedulers.fastest(model::ABM) = keys(model.agents)

"""
    Schedulers.by_id
A scheduler that activates all agents agents at each step according to their id.
"""
function Schedulers.by_id(model::ABM)
    agent_ids = sort(collect(keys(model.agents)))
    return agent_ids
end

"""
    Schedulers.randomly
A scheduler that activates all agents once per step in a random order.
Different random ordering is used at each different step.
"""
function Schedulers.randomly(model::ABM)
    order = shuffle(model.rng, collect(keys(model.agents)))
end

"""
    Schedulers.partially(p)
A scheduler that at each step activates only `p` percentage of randomly chosen agents.
"""
function Schedulers.partially(p::Real)
    function partial(model::ABM)
        ids = collect(keys(model.agents))
        return randsubseq(model.rng, ids, p)
    end
    return partial
end


"""
    Schedulers.by_property(property)
A scheduler that at each step activates the agents in an order dictated by their `property`,
with agents with greater `property` acting first. `property` can be a `Symbol`, which
just dictates which field of the agents to compare, or a function which inputs an agent
and outputs a real number.
"""
function Schedulers.by_property(p)
    function property(model::ABM)
        ids = collect(keys(model.agents))
        properties = [Agents.get_data(model[id], p) for id in ids]
        s = sortperm(properties)
        return ids[s]
    end
end


"""
    Schedulers.by_type(shuffle_types::Bool, shuffle_agents::Bool)
A scheduler useful only for mixed agent models using `Union` types.
- Setting `shuffle_types = true` groups by agent type, but randomizes the type order.
Otherwise returns agents grouped in order of appearance in the `Union`.
- `shuffle_agents = true` randomizes the order of agents within each group, `false` returns
the default order of the container (equivalent to [`Schedulers.fastest`](@ref)).
"""
function Schedulers.by_type(shuffle_types::Bool, shuffle_agents::Bool)
    function by_union(model::ABM{S,A}) where {S,A}
        types = union_types(A)
        sets = [Integer[] for _ in types]
        for agent in allagents(model)
            idx = findfirst(t -> t == typeof(agent), types)
            push!(sets[idx], agent.id)
        end
        shuffle_types && shuffle!(model.rng, sets)
        shuffle_agents && [shuffle!(model.rng, set) for set in sets]
        vcat(sets...)
    end
end

"""
    Schedulers.by_type((C, B, A), shuffle_agents::Bool)
A scheduler that activates agents by type in specified order (since `Union`s are not order
preserving). `shuffle_agents = true` randomizes the order of agents within each group.
"""
function Schedulers.by_type(order::Tuple{Type,Vararg{Type}}, shuffle_agents::Bool)
    function by_ordered_union(model::ABM{S,A}) where {S,A}
        types = union_types(A)
        if order !== nothing
            @assert length(types) == length(order) "Invalid dimension for `order`"
            types = order
        end
        sets = [Integer[] for _ in types]
        for agent in allagents(model)
            idx = findfirst(t -> t == typeof(agent), types)
            push!(sets[idx], agent.id)
        end
        shuffle_agents && [shuffle!(model.rng, set) for set in sets]
        vcat(sets...)
    end
end

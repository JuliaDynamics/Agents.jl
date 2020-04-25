####################################
# Schedulers
####################################

export random_activation, by_id, fastest, partial_activation, property_activation, by_type

"""
    fastest
Activate all agents once per step in the order dictated by the agent's container,
which is arbitrary (the keys sequence of a dictionary).
This is the fastest way to activate all agents once per step.
"""
fastest(model::ABM) = keys(model.agents)

"""
    by_id
Activate agents at each step according to their id.
"""
function by_id(model::ABM)
    agent_ids = sort(collect(keys(model.agents)))
    return agent_ids
end

@deprecate as_added by_id

"""
    random_activation
Activate agents once per step in a random order.
Different random ordering is used at each different step.
"""
function random_activation(model::ABM)
    order = shuffle(collect(keys(model.agents)))
end

"""
    partial_activation(p)
At each step, activate only `p` percentage of randomly chosen agents.
"""
function partial_activation(p::Real)
    function partial(model::ABM{A,S,F,P}) where {A,S,F,P}
        ids = collect(keys(model.agents))
        return randsubseq(ids, p)
    end
    return partial
end

"""
    property_activation(property)
At each step, activate the agents in an order dictated by their `property`,
with agents with greater `property` acting first. `property` is a `Symbol`, which
just dictates which field the agents to compare.
"""
function property_activation(p::Symbol)
    function by_property(model::ABM{A,S,F,P}) where {A,S,F,P}
        ids = collect(keys(model.agents))
        properties = [getproperty(model.agents[id], p) for id in ids]
        s = sortperm(properties)
        return ids[s]
    end
end

"""
    by_type(shuffle)
Useful only for mixed agent models using `Union` types.
Activate agents by type in order of appearance in the `Union`.
To group by type, but randomize the type order, set `shuffle = true`.
"""
function by_type(shuffle::Bool)
    function by_union(model::ABM{A,S,F,P}) where {A,S,F,P}
        types = union_types(A)
        sets = [Integer[] for _ in types]
        for agent in allagents(model)
            idx = findfirst(t -> t == typeof(agent), types)
            push!(sets[idx], agent.id)
        end
        shuffle && shuffle!(sets)
        vcat(sets...)
    end
end

"""
    by_type((C, B, A))
Activate agents by type in specified order (since `Union`s are not order preserving).
"""
function by_type(order::Tuple{Type, Vararg{Type}})
    function by_ordered_union(model::ABM{A,S,F,P}) where {A,S,F,P}
        types = union_types(A)
        if order != nothing
            @assert length(types) == length(order) "Invalid dimension for `order`"
            types = order
        end
        sets = [Integer[] for _ in types]
        for agent in allagents(model)
            idx = findfirst(t -> t == typeof(agent), types)
            push!(sets[idx], agent.id)
        end
        vcat(sets...)
    end
end

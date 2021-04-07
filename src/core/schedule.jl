export schedule
export schedule_randomly, schedule_by_id, schedule_fastest, schedule_partially, schedule_by_property, schedule_by_type
export random_activation, by_id, fastest, partial_activation, property_activation, by_type
"""
    schedule(model)
Return an iterator over the scheduled IDs using the model's scheduler.
"""
schedule(model::ABM) = model.scheduler(model)

####################################
# Schedulers
####################################
"""
    schedule_fastest
Activate all agents once per step in the order dictated by the agent's container,
which is arbitrary (the keys sequence of a dictionary).
This is the fastest way to activate all agents once per step.
"""
schedule_fastest(model::ABM) = keys(model.agents)

@deprecate fastest schedule_fastest

"""
    schedule_by_id
Activate agents at each step according to their id.
"""
function schedule_by_id(model::ABM)
    agent_ids = sort(collect(keys(model.agents)))
    return agent_ids
end

@deprecate by_id schedule_by_id
@deprecate as_added schedule_by_id

"""
    schedule_randomly
Activate agents once per step in a random order.
Different random ordering is used at each different step.
"""
function schedule_randomly(model::ABM)
    order = shuffle(model.rng, collect(keys(model.agents)))
end

@deprecate random_activation schedule_randomly

"""
    schedule_partially(p)
At each step, activate only `p` percentage of randomly chosen agents.
"""
function schedule_partially(p::Real)
    function partial(model::ABM)
        ids = collect(keys(model.agents))
        return randsubseq(model.rng, ids, p)
    end
    return partial
end

@deprecate partial_activation schedule_partially

"""
    schedule_by_property(property)
At each step, activate the agents in an order dictated by their `property`,
with agents with greater `property` acting first. `property` is a `Symbol`, which
just dictates which field the agents to compare.
"""
function schedule_by_property(p::Symbol)
    function by_property(model::ABM)
        ids = collect(keys(model.agents))
        properties = [getproperty(model.agents[id], p) for id in ids]
        s = sortperm(properties)
        return ids[s]
    end
end

@deprecate property_activation schedule_by_property

"""
    schedule_by_type(shuffle_types::Bool, shuffle_agents::Bool)
Useful only for mixed agent models using `Union` types.
- Setting `shuffle_types = true` groups by agent type, but randomizes the type order.
Otherwise returns agents grouped in order of appearance in the `Union`.
- `shuffle_agents = true` randomizes the order of agents within each group, `false` returns
the default order of the container (equivalent to [`fastest`](@ref)).
"""
function schedule_by_type(shuffle_types::Bool, shuffle_agents::Bool)
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

@deprecate by_type schedule_by_type

"""
    schedule_by_type((C, B, A), shuffle_agents::Bool)
Activate agents by type in specified order (since `Union`s are not order preserving).
`shuffle_agents = true` randomizes the order of agents within each group.
"""
function schedule_by_type(order::Tuple{Type,Vararg{Type}}, shuffle_agents::Bool)
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

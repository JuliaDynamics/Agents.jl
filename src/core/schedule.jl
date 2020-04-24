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

function fastest(sets::Vector{Vector{Integer}})
    vcat(sets...)
end

"""
    by_id
Activate agents at each step according to their id.
"""
function by_id(model::ABM)
    agent_ids = sort(collect(keys(model.agents)))
    return agent_ids
end

function by_id(sets::Vector{Vector{Integer}})
    [sort!(set) for set in sets]
    vcat(sets...)
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

function random_activation(sets::Vector{Vector{Integer}})
    [shuffle!(set) for set in sets]
    shuffle!(sets)
    vcat(sets...)
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

function partial_activation(sets::Vector{Vector{Integer}}, p::Real)
    subset = [randsubseq(set, p) for set in sets]
    vcat(subset...)
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
    by_type(fastest)
Useful only for mixed agent models using `Union` types.
Activate agents by type order, then by a subsequent `method`.

`method` may be any inbuilt scheduler listed above (except for `property_activation`),
or a custom function that accepts `sets::Vector{Vector{Integer}}` of agent ids separated
into `n` vectors, where `n` is the number of `AbstractAgent` types inside the `Union`.

Any additional scheduler properties are passed on, for example
`by_type(partial_activation, p)`.
"""
function by_type(method::Function, properties...)
    function by_union(model::ABM{A,S,F,P}) where {A,S,F,P}
        types = union_types(A)
        sets = [Integer[] for _ in types]
        for agent in allagents(model)
            idx = findfirst(t -> t == typeof(agent), types)
            push!(sets[idx], agent.id)
        end
        return method(sets, properties...)
    end
end


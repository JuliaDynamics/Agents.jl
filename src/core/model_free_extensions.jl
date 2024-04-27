# This file contains functions that are automatically enabled for all instances
# of `AgentBasedModels` that satisfy the mandatory API described by the abstract
# model interface. All these are public (exported) functions.
export random_agent, random_id, nagents, allagents, allids

"""
    model[id]
    getindex(model::ABM, id::Int)

Return an agent given its ID.
"""
Base.getindex(m::ABM, id::Integer) = agent_container(m)[id]

"""
    allids(model)
Return an iterator over all agent IDs of the model.
"""
allids(model) = eachindex(agent_container(model))

"""
    allagents(model)
Return an iterator over all agents of the model.
"""
allagents(model) = values(agent_container(model))

"""
    nagents(model::ABM)
Return the number of agents in the `model`.
"""
nagents(model::ABM) = length(allids(model))

"""
    random_id(model) → id

Return a random id from the model.
"""
random_id(model) = rand(abmrng(model), allids(model))

"""
    random_agent(model) → agent

Return a random agent from the model.
"""
random_agent(model) = model[random_id(model)]

"""
    random_agent(model, condition; optimistic=true, alloc = false) → agent

Return a random agent from the model that satisfies `condition(agent) == true`.
The function generates a random permutation of agent IDs and iterates through
them. If no agent satisfies the condition, `nothing` is returned instead.

## Keywords

`optimistic = true` changes the algorithm used to be non-allocating but
potentially more variable in performance. This should be faster if the condition
is `true` for a large proportion of the population (for example if the agents
are split into groups).

`alloc` can be used to employ a different fallback strategy in case the
optimistic version doesn't find any agent satisfying the condition: if the filtering
condition is expensive an allocating fallback can be more performant.
"""
function random_agent(model, condition; optimistic = true, alloc = false)
    if optimistic
        return optimistic_random_agent(model, condition, alloc)
    else
        return fallback_random_agent(model, condition, alloc)
    end
end

function optimistic_random_agent(model, condition, alloc; n_attempts = nagents(model))
    @inbounds while n_attempts != 0
        idx = random_id(model)
        condition(model[idx]) && return model[idx]
        n_attempts -= 1
    end
    return fallback_random_agent(model, condition, alloc)
end

function fallback_random_agent(model, condition, alloc)
    if alloc
        iter_ids = allids(model)
        id = sampling_with_condition_single(iter_ids, condition, model, id -> model[id])
        isnothing(id) && return nothing
        return model[id]
    else
        iter_agents = allagents(model)
        iter_filtered = Iterators.filter(agent -> condition(agent), iter_agents)
        agent = itsample(abmrng(model), iter_filtered, StreamSampling.AlgL())
        isnothing(agent) && return nothing
        return agent
    end
end

function remove_all_from_model!(model::ABM)
    for a in allagents(model)
        remove_agent_from_model!(a, model)
    end
end

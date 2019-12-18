export sample!, genocide!
using StatsBase: sample, Weights

"""
    genocide!(model::ABM)
Kill all the agents of the model.
"""
function genocide!(model::ABM)
    for (i, a) in model.agents
        kill_agent!(a, model)
    end
    return model
end

"""
    sample!(model::ABM, n [, weight]; kwargs...)

Replace the agents of the `model` with a random sample of the current agents with
size `n`.

Optionally, choose an agent property `weight` (Symbol) to weight the sampling.
This means that the higher the `weight` of the agent, the higher the probability that
this agent will be chosen in the new sampling.

# Keywords
* `replace = true` : whether sampling is performed with replacement, i.e. all agents can
  be chosen more than once.
* `rng = GLOBAL_RNG` : a random number generator to perform the sampling with.

See the Wright-Fisher example in the documentation for an application of `sample!`.
"""
function sample!(model::ABM, n::Int, weight=nothing; replace=true,
    rng::AbstractRNG=Random.GLOBAL_RNG)

    if weight != nothing
        weights = Weights([getproperty(a, weight) for a in values(model.agents)])
        newids = sample(rng, collect(keys(model.agents)), weights, n, replace=replace)
    else
        newids = sample(rng, collect(keys(model.agents)), n, replace=replace)
    end

    # newagents = [deepcopy(model.agents[i]) for i in newids]
    # genocide!(model)
    agentfields = fieldnames(Agents.agenttype(model))
    agentsnum = nagents(model)
    for (index, id) in enumerate(newids) # add new agents while adjusting id
        model.agents[index] = deepcopy(model.agents[id])
        if :pos in agentfields
            model.space
        end
        model.agents[index].id = id
        if index > agentsnum  # add agents to the space too
            a = deepcopy(model.agents[id])
            a.id = index
            add_agent_pos!(a, model)
        end
    end
    # kill extra agents
    if n< agentsnum
        for (k, v) in model.agents
            if k > n
                kill_agent!(k, model)
            end
        end
    end
    return model
end

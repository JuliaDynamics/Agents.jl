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
    genocide!(model::ABM, n::Int)
Kill the agents of the model whose IDs are larger than n.
"""
function genocide!(model::ABM, n::Int)
    for (k, v) in model.agents
        if k > n
            kill_agent!(v, model)
        end
    end
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

    for (index, id) in enumerate(newids) # add new agents while adjusting id
        model.agents[index] = deepcopy(model.agents[id])
        model.agents[index].id = index
    end
    # kill extra agents
    if n < nagents(model)
        genocide!(model, n)
    end
    # Clean space
    clean_space!(model)

    return model
end

"""
Remove all IDs from space and add agent ids again.
"""
function clean_space!(model::ABM)
    if model.space != nothing
        for node in 1:nv(model)
            model.space.agent_positions[node] = Int[]
        end
        for (k, v) in model.agents
            push!(model.space.agent_positions[pos_vertex(v.pos, model)], v.id)
        end
    end
end
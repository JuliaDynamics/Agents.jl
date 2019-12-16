export sample!
using StatsBase: sample, Weights

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
"""
function sample!(model::ABM, n::Int, weight=nothing; replace=true,
    rng::AbstractRNG=Random.GLOBAL_RNG)

    if weight != nothing
        weights = Weights([getproperty(a, weight) for a in values(model.agents)])
        newids = sample(rng, collect(keys(model.agents)), weights, n, replace=replace)
    else
        newids = sample(rng, collect(keys(model.agents)), n, replace=replace)
    end

    newagents = [deepcopy(model.agents[i]) for i in newids]

    fnames = fieldnames(Agents.agenttype(model))
    haspos = in(:pos, fnames)

    if haspos
      for v in values(model.agents)
        kill_agent!(v, model)
      end
      for (index, ag) in enumerate(newagents)
        ag.id = index
        add_agent!(ag, ag.pos, model)
      end
    else
      for k in keys(model.agents)
        delete!(model.agents, k)
      end
      for (index, ag) in enumerate(newagents)
        ag.id = index
        model.agents[index] = ag
      end
    end
end

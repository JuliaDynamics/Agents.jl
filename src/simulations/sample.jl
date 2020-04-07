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

See the Wright-Fisher example in the documentation for an application of `sample!`.
"""
function sample!(model::ABM{A, S}, n::Int, weight=nothing; replace=true,
  rng::AbstractRNG=Random.GLOBAL_RNG) where{A, S}
  
  nagents(model) > 0 || return

  org_ids = collect(keys(model.agents))
  if weight != nothing
    weights = Weights([getproperty(a, weight) for a in values(model.agents)])
    newids = sample(rng, org_ids, weights, n, replace=replace)
  else
    newids = sample(rng, org_ids, n, replace=replace)
  end

  add_function = hasfield(A, :pos) ? add_agent_pos! : add_agent!
  nextid = maximum(keys(model.agents)) + 1
  for id in org_ids
    if !in(id, newids)
      kill_agent!(model.agents[id], model)
    else
      noccurances = count(x->x==id, newids)
      for t in 2:noccurances
        newagent = deepcopy(model.agents[id])
        newagent.id = nextid
        add_function(newagent, model)
        nextid += 1
      end
    end
  end
end

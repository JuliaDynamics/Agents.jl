export sample!
using StatsBase: sample, Weights

"""
    sample!(model::ABM, n [, weight]; kwargs...)

Replace the agents of the `model` with a random sample of the current agents with
size `n`.

Optionally, provide a `weight`: Symbol (agent field) or function (input agent
out put number) to weight the sampling.
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
    weights = Weights([get_data(a, weight, Identity) for a in values(model.agents)])
    newids = sample(rng, org_ids, weights, n, replace=replace)
  else
    newids = sample(rng, org_ids, n, replace=replace)
  end
  add_newids!(model, org_ids, newids)
end

"Used in sample!"
function add_newids!(model, org_ids, newids)
  n = nextid(model)
  for id in org_ids
    if !in(id, newids)
      kill_agent!(model.agents[id], model)
    else
      noccurances = count(x->x==id, newids)
      for t in 2:noccurances
        newagent = deepcopy(model.agents[id])
        newagent.id = n
        add_agent_pos!(newagent, model)
        n += 1
      end
    end
  end
end

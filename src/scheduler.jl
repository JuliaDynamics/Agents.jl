
"""
    as_added(model::AbstractModel)

Activates agents at each step in the same order as they have been added to the model.
"""
function as_added(model::AbstractModel)
  agent_ids = [i.id for i in model.agents]
  return sortperm(agent_ids)
end

"""
    random_activation(model::AbstractModel)

Activates agents once per step in a random order.
"""
function random_activation(model::AbstractModel)
  order = shuffle(1:length(model.agents))
end

"""
    partial_activation(model::AbstractModel)

At each step, activates only `activation_prob` number of randomly chosen of individuals with a `activation_prob` probability. `activation_prob` should be a field in the model and between 0 and 1.
"""
function partial_activation(model::AbstractModel)
  agentnum = nagents(model)
  return randsubseq(1:agentnum, model.activation_prob)
end

function return_activation_order(model::AbstractModel)
  order = model.scheduler(model)
end


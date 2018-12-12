
"""
    as_added(model::AbstractModel)

Activates all agents at each step as they have been added to the model.
"""
function as_added(model::AbstractModel)
  agent_ids = [i.id for i in model.agents]
  return sortperm(agent_ids)
end

"""
    random_activation(model::AbstractModel)

Activates all agents randomly at each step.
"""
function random_activation(model::AbstractModel)
  order = shuffle(1:length(model.agents))
end


function return_activation_order(model::AbstractModel)
  order = model.scheduler(model)
end


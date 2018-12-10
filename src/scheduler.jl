
"""
Update the agents as they have been added to the schedules
"""
function as_added()
  #TODO
end

"""
Activates all the agents once per step, in random order.
"""
function random_activation(model::AbstractModel)
  order = shuffle(1:length(model.agents))
end


function return_activation_order(model::AbstractModel)
  order = model.scheduler(model)
end


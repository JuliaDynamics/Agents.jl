
"""
Define your model to be a subtype of `AbstractModel`. Your model has to have the following fields, but can also have other fields of your choice.

e.g.

```
mutable struct MyModel <: AbstractModel
  scheduler::Function
  grid
  agents::Array{Integer}  # a list of agents ids
end
```

`scheduler` can be one of the default functions (`random_activation`), or your own function.
"""
abstract type AbstractModel end

nagents(model::AbstractModel) = length(model.agents)

"""
The step function
"""
function step!(agent_step::Function, model::AbstractModel)
  activation_order = return_activation_order(model)
  for index in activation_order
    agent_step(model.agents[index], model)
  end
end

"""
Repeat the `step` function `repeat` times.
"""
function step!(agent_step::Function, model::AbstractModel, repeat::Integer)
  for i in 1:repeat
    step!(agent_step, model)
  end
end
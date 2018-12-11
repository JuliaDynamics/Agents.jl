
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
    step!(agent_step::Function, model::AbstractModel)

The step function of an agent.
"""
function step!(agent_step, model::AbstractModel)
  activation_order = return_activation_order(model)
  for index in activation_order
    agent_step(model.agents[index], model)
  end
end

"""
    step!(agent_step::Function, model::AbstractModel, nsteps::Integer)

Repeat the `step` function `nsteps` times.

Does not collect data.
"""
function step!(agent_step, model::AbstractModel, nsteps::Integer)
  for i in 1:nsteps
    step!(agent_step, model)
  end
end

"""
Repeat the `step` function `nsteps` times.

"""
function step!(agent_step::Function, model::AbstractModel, nsteps::Integer, properties::Array{Symbol}, steps_to_collect_data::Array{Int64})

  # Run the first step of the model to fill in the dataframe
  step!(agent_step, model)
  df = data_collector(properties, steps_to_collect_data, model, 1)

  for ss in 1:nsteps
    step!(agent_step, model)
    # collect data
    if ss in steps_to_collect_data
      df = data_collector(properties, steps_to_collect_data, model, ss, df)
    end
  end
  # if 1 is not in `steps_to_collect_data`, remove the first row.
  if !in(1, steps_to_collect_data)
    df = df[2:end, :]
  end
  return df
end

"""
    step!(agent_step::Function, model::AbstractModel, nsteps::Integer, properties::Array{Symbol}, aggregators::Array{Function}, steps_to_collect_data::Array{Integer})

Repeat the `step` function `nsteps` times.

Includes an aggregator to collect data.
"""
function step!(agent_step, model::AbstractModel, nsteps::Integer, properties::Array{Symbol}, aggregators::Array{Function}, steps_to_collect_data::Array{Int64})
  
  # Run the first step of the model to fill in the dataframe
  step!(agent_step, model)
  df = data_collector(properties, aggregators, steps_to_collect_data, model, 1)

  for ss in 2:nsteps
    step!(agent_step, model)
    # collect data
    if ss in steps_to_collect_data
      df = data_collector(properties, aggregators, steps_to_collect_data, model, ss, df)
    end
  end
  # if 1 is not in `steps_to_collect_data`, remove the first row.
  if !in(1, steps_to_collect_data)
    df = df[2:end, :]
  end
  return df
end


"""
    step!(agent_step::Function, model_step::Function, model::AbstractModel)

The step function with `agent_step` and `model_step` functions.
"""
function step!(agent_step, model_step, model::AbstractModel)
  activation_order = return_activation_order(model)
  for index in activation_order
    agent_step(model.agents[index], model)
  end
  model_step(model)
end

"""
    step!(agent_step::Function, model_step::Function, model::AbstractModel, nsteps::Integer)

Repeat the `step` function `nsteps` times.

Does not collect data.
"""
function step!(agent_step, model_step, model::AbstractModel, nsteps::Integer)
  for ss in 1:nsteps
    step!(agent_step, model_step, model)
  end
end

"""
    step!(agent_step::Function, model_step::Function, model::AbstractModel, nsteps::Integer, properties::Array{Symbol}, steps_to_collect_data::Array{Integer})
Repeat the `step` function `nsteps` times.

Does not include an aggregator, collects raw data.
"""
function step!(agent_step, model_step, model::AbstractModel, nsteps::Integer, properties::Array{Symbol}, steps_to_collect_data::Array{Int64})

  # Run the first step of the model to fill in the dataframe
  step!(agent_step, model_step, model)
  df = data_collector(properties, steps_to_collect_data, model, 1)

  for ss in 2:nsteps
    step!(agent_step, model_step, model)
    # collect data
    if ss in steps_to_collect_data
      df = data_collector(properties, steps_to_collect_data, model, ss, df)
    end
  end
  # if 1 is not in `steps_to_collect_data`, remove the first row.
  if !in(1, steps_to_collect_data)
    df = df[2:end, :]
  end
  return df
end

"""
    step!(agent_step::Function, model_step::Function, model::AbstractModel, nsteps::Integer, properties::Array{Symbol}, aggregators::Array{Function}, steps_to_collect_data::Array{Integer})

Repeat the `step` function `nsteps` times.

Includes an aggregator to collect data.
"""
function step!(agent_step, model_step, model::AbstractModel, nsteps::Integer, properties::Array{Symbol}, aggregators::Array{Function}, steps_to_collect_data::Array{Int64})
  
  # Run the first step of the model to fill in the dataframe
  step!(agent_step, model_step, model)
  df = data_collector(properties, aggregators, steps_to_collect_data, model, 1)

  for ss in 2:nsteps
    step!(agent_step, model_step, model)
    # collect data
    if ss in steps_to_collect_data
      df = data_collector(properties, aggregators, steps_to_collect_data, model, ss, df)
    end
  end
  # if 1 is not in `steps_to_collect_data`, remove the first row.
  if !in(1, steps_to_collect_data)
    df = df[2:end, :]
  end
  return df
end

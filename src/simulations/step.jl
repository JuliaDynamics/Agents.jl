export step!

"""
    step!(agent_step! [, model_step!], model::AbstractModel, n::Int = 1)

Update agents `n` steps. Agents will be updated as specified by the `model.scheduler`.
If given the optional function `model_step!`, it is triggered _after_ every scheduled
agent has acted.


# TODO: CHANGE THIS FUNCTION NAME!
    step!(agent_step! [, model_step!], model, n, properties, when)

This version of `step!` also performs data collection, by collecting the properties
of the Agent type dictated by `properties <: AbstractArray{Symbol}`. The collection happens
at the steps indicated by `when <: AbstractArray{Int}`
"""
function step! end

#######################################################################################
# basic stepping
#######################################################################################
function step!(agent_step!, model::AbstractModel)
  activation_order = return_activation_order(model)
  for index in activation_order
    agent_step!(model.agents[index], model)
  end
end
function step!(agent_step!, model::AbstractModel, n::Int)
  for i in 1:n
    step!(agent_step!, model)
  end
end

function step!(agent_step!, model_step!, model::AbstractModel)
  activation_order = return_activation_order(model)
  for index in activation_order
    agent_step!(model.agents[index], model)
  end
  model_step!(model)
end
function step!(agent_step!, model_step!, model::AbstractModel, n::Int)
  for ss in 1:nsteps
    step!(agent_step!, model_step!, model)
  end
end

#######################################################################################
# data collection
#######################################################################################
function step!(agent_step!::Function, model::AbstractModel, nsteps::Integer, agent_properties::Array{Symbol}, steps_to_collect_data::Array{Int64})

  # Run the first step of the model to fill in the dataframe
  # step!(agent_step!, model)
  df = data_collector(agent_properties, steps_to_collect_data, model, 1)

  for ss in 2:nsteps
    step!(agent_step!, model)
    # collect data
    if ss in steps_to_collect_data
      df = data_collector(agent_properties, steps_to_collect_data, model, ss, df)
    end
  end
  # if 1 is not in `steps_to_collect_data`, remove the first row.
  if !in(1, steps_to_collect_data)
    df = df[2:end, :]
  end
  return df
end

"""
    step!(agent_step!::Function, model::AbstractModel, nsteps::Integer, agent_properties::Array{Symbol}, aggregators::Array, steps_to_collect_data::Array{Integer})

Repeats the `step` function `nsteps` times, and applies functions in `aggregators` to values of agent fields in `agent_properties` at steps `steps_to_collect_data`.
"""
function step!(agent_step!, model::AbstractModel, nsteps::Integer, agent_properties::Array{Symbol}, aggregators::Array, steps_to_collect_data::Array{Int64})

  # Run the first step of the model to fill in the dataframe
  # step!(agent_step!, model)
  df = data_collector(agent_properties, aggregators, steps_to_collect_data, model, 1)

  for ss in 2:nsteps
    step!(agent_step!, model)
    # collect data
    if ss in steps_to_collect_data
      df = data_collector(agent_properties, aggregators, steps_to_collect_data, model, ss, df)
    end
  end
  # if 1 is not in `steps_to_collect_data`, remove the first row.
  if !in(1, steps_to_collect_data)
    df = df[2:end, :]
  end
  return df
end

"""
    step!(agent_step!::Function, model::AbstractModel, nsteps::Integer, propagg::Dict, steps_to_collect_data::Array{Integer})

Repeats the `step` function `nsteps` times, and applies functions in values of the `propagg` dict to its keys at steps `steps_to_collect_data`.
"""
function step!(agent_step!, model::AbstractModel, nsteps::Integer, propagg::Dict, steps_to_collect_data::Array{Int64})

  # Run the first step of the model to fill in the dataframe
  # step!(agent_step!, model)
  df = data_collector(propagg, steps_to_collect_data, model, 1)

  for ss in 2:nsteps
    step!(agent_step!, model)
    # collect data
    if ss in steps_to_collect_data
      df = data_collector(propagg, steps_to_collect_data, model, ss, df)
    end
  end
  # if 1 is not in `steps_to_collect_data`, remove the first row.
  if !in(1, steps_to_collect_data)
    df = df[2:end, :]
  end
  return df
end

"""
    step!(agent_step!::Function, model_step!::Function, model::AbstractModel, nsteps::Integer, agent_properties::Array{Symbol}, steps_to_collect_data::Array{Integer})

Repeats the `step` function `nsteps` times, and collects all agent fields in `agent_properties` at steps `steps_to_collect_data`.
"""
function step!(agent_step!, model_step!, model::AbstractModel, nsteps::Integer, agent_properties::Array{Symbol}, steps_to_collect_data::Array{Int64})

  # Run the first step of the model to fill in the dataframe
  # step!(agent_step!, model_step!, model)
  df = data_collector(agent_properties, steps_to_collect_data, model, 1)

  for ss in 2:nsteps
    step!(agent_step!, model_step!, model)
    # collect data
    if ss in steps_to_collect_data
      df = data_collector(agent_properties, steps_to_collect_data, model, ss, df)
    end
  end
  # if 1 is not in `steps_to_collect_data`, remove the first columns. TODO: remove ids that were only present in the first step
  if !in(1, steps_to_collect_data)
    first_col = length(agent_properties)+2 # 1 for id and 1 for passing these agent properties
    end_col = size(df, 2)
    df = df[:, vcat([1], collect(first_col:end_col))]
  end
  return df
end

"""
    step!(agent_step!::Function, model_step!::Function, model::AbstractModel, nsteps::Integer, agent_properties::Array{Symbol}, aggregators::Array, steps_to_collect_data::Array{Integer})

Repeats the `step` function `nsteps` times, and applies functions in `aggregators` to values of agent fields in `agent_properties` at steps `steps_to_collect_data`.
"""
function step!(agent_step!, model_step!, model::AbstractModel, nsteps::Integer, agent_properties::Array{Symbol}, aggregators::Array, steps_to_collect_data::Array{Int64})

  # Run the first step of the model to fill in the dataframe
  # step!(agent_step!, model_step!, model)
  df = data_collector(agent_properties, aggregators, steps_to_collect_data, model, 1)

  for ss in 2:nsteps
    step!(agent_step!, model_step!, model)
    # collect data
    if ss in steps_to_collect_data
      df = data_collector(agent_properties, aggregators, steps_to_collect_data, model, ss, df)
    end
  end
  # if 1 is not in `steps_to_collect_data`, remove the first row.
  if !in(1, steps_to_collect_data)
    df = df[2:end, :]
  end
  return df
end

"""
    step!(agent_step!::Function, model_step!::Function, model::AbstractModel, nsteps::Integer, propagg::Dict, steps_to_collect_data::Array{Integer})

Repeats the `step` function `nsteps` times, and applies functions in values of the `propagg` dict to its keys at steps `steps_to_collect_data`.
"""
function step!(agent_step!, model_step!, model::AbstractModel, nsteps::Integer, propagg::Dict, steps_to_collect_data::Array{Int64})

  # Run the first step of the model to fill in the dataframe
  # step!(agent_step!, model_step!, model)
  df = data_collector(propagg, steps_to_collect_data, model, 1)

  for ss in 2:nsteps
    step!(agent_step!, model_step!, model)
    # collect data
    if ss in steps_to_collect_data
      df = data_collector(propagg, steps_to_collect_data, model, ss, df)
    end
  end
  # if 1 is not in `steps_to_collect_data`, remove the first row.
  if !in(1, steps_to_collect_data)
    df = df[2:end, :]
  end
  return df
end

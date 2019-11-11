export step!, dummystep

"""
    step!(model, agent_step! [, model_step!], n::Int = 1)

Update agents `n` steps. Agents will be updated as specified by the `model.scheduler`.
If given the optional function `model_step!`, it is triggered _after_ every scheduled
agent has acted.

    step!(model, agent_step! [, model_step!], n [, properties]; kwargs...)

This version of `step!` also performs data collection/processing while
running the model.

`properties` dictates which agent fields should be collected as data.
It can be either an array, in which case agent fields will be saved as they are.
Or it can be a dictionary, in which case it should map agent fields (`Symbol`) to functions.
These functions are applied to the collected fields, that is, the keys of `properties`.
For example, if your agents have a field called `wealth`,
and you want to calculate mean and median population wealth at steps defined
by `when`, your `properties` dict will be `Dict(:wealth => [mean, median])`.

If an agent field returns an array instead of a single number, the mean of that
array will be calculated before the functions are applied to them.

To apply a function to the list of agents, use `:agent` as a dictionary key.
To apply a function to the model object, use `:model` as a dictionary key.

### Keywords
* `when` : at which steps `n` to perform the data collection and processing.
* `nreplicates` : Optional. Run `nreplicates` replicates of the simulation. Defaults to 0.
* `parallel` : Optional. Only when `nreplicates`>0. Run replicate simulations in parallel. Defaults to `false`.
"""
function step! end

#######################################################################################
# basic stepping
#######################################################################################
dummystep(model) = nothing
dummystep(agent, model) = nothing

step!(model::AbstractModel, agent_step!, n::Int = 1) = step!(model, agent_step!, dummystep, n)

function step!(model::AbstractModel, agent_step!, model_step!, n::Int = 1)
  for i in 1:n
    activation_order = model.scheduler(model)
    for index in activation_order
      agent_step!(model.agents[index], model)
    end
    model_step!(model)
  end
end

#######################################################################################
# data collection
#######################################################################################

step!(model::AbstractModel, agent_step!, n::Int, properties; parallel::Bool=false, when::AbstractArray{Int}=[1], nreplicates::Int=0) = step!(model, agent_step!, dummystep, n, properties, when=when, nreplicates=nreplicates, parallel=parallel)

function step!(model::AbstractModel, agent_step!, model_step!, n::Int, properties; when::AbstractArray{Int}=[1], nreplicates::Int=0, parallel::Bool=false)

  single_df = true
  if typeof(properties) <: AbstractArray # if the user is collecting raw data, it is best to save a list of dataframes for each simulation replicate
    single_df = false
  end

  if nreplicates > 0
    if parallel
      dataall = parallel_replicates(model, agent_step!, model_step!, n, properties, when=when, nreplicates=nreplicates, single_df=single_df)
    else
      if single_df
        dataall = _step(deepcopy(model), agent_step!, model_step!, properties, when, n)
      else
        dataall = [_step(deepcopy(model), agent_step!, model_step!, properties, when, n)]
      end
      for i in 2:nreplicates
        data = _step(deepcopy(model), agent_step!, model_step!, properties, when, n)
        if single_df
          dataall = join(dataall, data, on=:step, kind=:outer, makeunique=true)
        else
          push!(dataall, data)
        end
      end
    end
    return dataall
  end

  df = _step(model, agent_step!, model_step!, properties, when, n)

  if !in(1, when)
    if typeof(properties) <: Dict
    # if 1 is not in `when`, remove the first columns. TODO: remove ids that were only present in the first step
      first_col = length(properties)+2 # 1 for id and 1 for passing these agent properties
      end_col = size(df, 2)
      df = df[:, vcat([1], collect(first_col:end_col))]
    else
      # if 1 is not in `when`, remove the first row.
      df = df[2:end, :]
    end
  end

  return df
end

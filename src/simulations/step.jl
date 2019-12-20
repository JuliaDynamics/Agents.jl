export step!, dummystep

"""
    step!(model, agent_step! [, model_step!], n::Integer = 1)

Update agents `n` steps. Agents will be updated as specified by the `model.scheduler`.
If given the optional function `model_step!`, it is triggered _after_ every scheduled
agent has acted.

    step!(model, agent_step! [, model_step!], n::Function)

`n` can be also be a function that takes as an input the `model` and returns
`true/false`. Then `step!` runs the model until `n(model)` returns `true`.

    step!(model, agent_step! [, model_step!], n, properties; kwargs...)

This version of `step!`, with the `properties` argument and extra keywords,
performs data collection/processing while running the model.

`properties` dictates which agent fields should be collected as data.
It can be either an array, in which case, the specified fields of all agents will be
saved.
Or it can be a dictionary, in which case it should map agent fields (`Symbol`) to functions.

If `properties` is an array, each row of the output `DataFrame` corresponds to a
single agent and each column is a requested field value.

If `properties` is a dictionary, each row of the output `DataFrame` corresponds to
all agents and each column is the a function applied to a field. The functions in a
dictionary `properties` are applied to the collected fields, that is, the keys of
`properties`.
For example, if your agents have a field called `wealth`,
and you want to calculate mean and median population wealth at steps defined
by `when`, your `properties` dict will be `Dict(:wealth => [mean, median])`.

If an agent field returns an array instead of a single number, the mean of that
array will be calculated before the functions are applied to them.

Collected data always also include the initial status of the model at step 0.

To apply a function to the list of agents, use `:agent` as a dictionary key.
To apply a function to the model object, use `:model` as a dictionary key.

### Keywords
* `when=1:n` : at which steps `n` to perform the data collection and processing.
* `replicates` : Optional. Run `replicates` replicates of the simulation. Defaults to 0.
* `parallel` : Optional. Only when `replicates`>0. Run replicate simulations in parallel. Defaults to `false`.
* `step0`: Whether to collect data at step zero, before running the model. Defaults to true.
"""
function step! end

#######################################################################################
# basic stepping
#######################################################################################
dummystep(model) = nothing
dummystep(agent, model) = nothing

step!(model::ABM, agent_step!, n::Int = 1) = step!(model, agent_step!, dummystep, n)

function step!(model::ABM, agent_step!::F, model_step!::G, n::Int = 1) where {F<:Function, G<:Function}
  for i in 1:n
    activation_order = model.scheduler(model)
    for index in activation_order
      agent_step!(model.agents[index], model)
    end
    model_step!(model)
  end
end

function step!(model::ABM, agent_step!::F, model_step!::G, n::H) where {F<:Function, G<:Function, H<:Function}
  while !n(model)
    step!(model, agent_step!, model_step!, 1)
  end
end

#######################################################################################
# data collection
#######################################################################################

step!(model::ABM, agent_step!, n, properties; parallel::Bool=false, when::AbstractArray{Int}=1:n, replicates::Int=0, step0::Bool=true) = step!(model, agent_step!, dummystep, n, properties, when=when, replicates=replicates, parallel=parallel, step0=step0)

function step!(model::ABM, agent_step!, model_step!, n, properties; when::AbstractArray{Int}=1:n, replicates::Int=0, parallel::Bool=false, step0::Bool=true)

  if replicates > 0
    if parallel
      dataall = parallel_replicates(model, agent_step!, model_step!, n, properties, when=when, replicates=replicates, step0=step0)
    else
      dataall = series_replicates(model, agent_step!, model_step!, properties, when, n, replicates, step0)
    end
    return dataall
  end

  df = _step!(model, agent_step!, model_step!, properties, when, n, step0)

  return df
end

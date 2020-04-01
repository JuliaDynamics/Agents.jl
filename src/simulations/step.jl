export step!, dummystep

"""
    step!(model, agent_step! [, model_step!], n::Integer = 1)

Update agents `n` steps. Agents will be updated as specified by the `model.scheduler`.
If given the optional function `model_step!`, it is triggered _after_ every scheduled
agent has acted.

    step!(model, agent_step! [, model_step!], n::Function)

`n` can be also be a function that takes as an input the `model` and returns
`true/false`. Then `step!` runs the model until `n(model)` returns `true`.

    step!(model, agent_step! [, model_step!], n, agent_properties [, model_properties];
            aggregation_dict, kwargs...)

This version of `step!`, with the `*_properties` arguments and extra keywords,
performs data collection/processing while running the model.

`agent_properties` dictates which agent fields should be collected as data.
It can be either an array, in which case, the specified fields of all agents will be
saved.
Or it can be a dictionary, in which case it should map agent fields (`Symbol`) to functions.

If `agent_properties` is an array, each row of the output `DataFrame` corresponds to a
single agent and each column is a requested field value.

If `agent_properties` is a dictionary, each row of the output `DataFrame` corresponds to
all agents and each column is the result of a function applied to a specific field.
The functions in an `agent_properties` are applied to the collected fields, that is,
the keys of `agent_properties`.
For example, if your agents have a field called `wealth`, and you want to calculate the
mean and median wealth of all agents at steps defined by `when`, your `agent_properties`
dictionary will be `Dict(:wealth => [mean, median])`.

If an agent field returns an array instead of a single number, the mean of that
array will be calculated before the functions are applied to them.

The same functionality exists for `model` using `model_properties`.

`aggregation_dict`: TODO. May actually be separated aspects of the above discussion ####

By default, collected data includes the initial status of the model at step 0.

### Keywords
* `collect0`: Whether to collect data at step zero, before running the model. Defaults to true.
* `when=1:n` : at which steps `n` to perform the data collection and processing.
* `when=f(model)` : data collection will occur when the function returns `true`.
* `replicates` : Optional. Run `replicates` replicates of the simulation. Defaults to 0.
* `parallel` : Optional. Only when `replicates`>0. Run replicate simulations in parallel. Defaults to `false`.
"""
function step! end

#######################################################################################
# basic stepping
#######################################################################################
"""
    dummystep(model)

Ignore the model dynamics on this `step!`. Use instead of `model_step!`.
"""
dummystep(model) = nothing
"""
    dummystep(agent, model)

Ignore the agent dynamics on this `step!`. Use instead of `agent_step!`.
"""
dummystep(agent, model) = nothing

until(ss, n::Int, model) = ss < n
until(ss, n::Function, model) = !n(model)

step!(model::ABM, agent_step!, n::Int = 1) = step!(model, agent_step!, dummystep, n)

function step!(model::ABM, agent_step!, model_step!, n) where {F<:Function, G<:Function}
  s = 0
  while until(s, n, model)
    activation_order = model.scheduler(model)
    for index in activation_order
      agent_step!(model.agents[index], model)
    end
    model_step!(model)
    s += 1
  end
end

#######################################################################################
# data collection
#######################################################################################

step!(model::ABM, agent_step!, n, agent_properties; collect0::Bool=true, when=1:n, parallel::Bool=false, replicates::Int=0) = step!(model, agent_step!, dummystep, n; collect0=collect0, when=when, agent_properties=agent_properties, replicates=replicates, parallel=parallel)

function step!(model::ABM, agent_step!, model_step!, n; collect0::Bool=true, when=1:n, agent_properties=nothing, model_properties=nothing, aggregation_dict=nothing, replicates::Int=0, parallel::Bool=false)

  if replicates > 0
    if parallel
      dataall = parallel_replicates(model, agent_step!, model_step!, n, when; agent_properties=agent_properties, model_properties=model_properties, aggregation_dict=aggregation_dict, replicates=replicates)
    else
      dataall = series_replicates(model, agent_step!, model_step!, n, when; agent_properties=agent_properties, model_properties=model_properties, aggregation_dict=aggregation_dict, replicates=replicates)
    end
    return dataall
  end

  df = run!(model, agent_step!, model_step!, n; collect0=collect0, when=when, agent_properties=agent_properties, model_properties=model_properties, aggregation_dict=aggregation_dict)

  return df
end

export step!, dummystep

"""
    step!(model, agent_step! [, model_step!], n::Integer = 1)

Run the model for `n` steps. Agents will be updated as specified by the `model.scheduler`.
If given the optional function `model_step!`, it is triggered _after_ every scheduled
agent has acted.

    step!(model, agent_step! [, model_step!], n::Function)

`n` can be also be a function that takes as an input the `model` and current step number `s`
and returns `true/false`. Then `step!` runs the model until `n(model, s)` returns `true`.
Having the `s` number as an argument is useful to add a fail-safe to your function
(in case you don't want to let your model run *too* long).

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
* `when=true` : at which steps `n` to perform the data collection and processing.
  `true` means at all steps, otherwise you can specify steps explicitly like `1:5:1000`.
* `Nmax=Inf` : if the step number becomes `> Nmax`, evolution is terminated (only used
  in the case `n::Function`).
* `replicates` : Optional. Run `replicates` replicates of the simulation. Defaults to 0.
* `parallel` : Optional. Only when `replicates`>0. Run replicate simulations in parallel. Defaults to `false`.
* `step0`: Whether to collect data at step zero, before running the model. Defaults to true.
"""
function step! end

#######################################################################################
# basic stepping
#######################################################################################
dummystep(args...) = nothing

step!(model::ABM, agent_step!, n::Union{Integer, Function} = 1) =
step!(model, agent_step!, dummystep, n)

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
  s = 1
  while !n(model, s)
    step!(model, agent_step!, model_step!, 1)
    s+=1
  end
end

#######################################################################################
# data collection
#######################################################################################

step!(model::ABM, agent_step!, n, properties; kwargs...) =
step!(model, agent_step!, dummystep, n, properties; kwargs...)

function step!(model::ABM, agent_step!, model_step!, n, properties;
  parallel::Bool=false, kwargs...)

  if replicates > 0
    if parallel
      dataall = parallel_replicates(model, agent_step!, model_step!, n, properties; kwargs...)
    else
      dataall = series_replicates(model, agent_step!, model_step!, n, properties; kwargs...)
    end
    return dataall
  end
  df = _step!(model, agent_step!, model_step!, properties, when, n, step0)
  return df
end

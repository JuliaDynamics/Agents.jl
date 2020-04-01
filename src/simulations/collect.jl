###################################################
# Definition of the data collection API
###################################################
get_data(a, s::Symbol) = getproperty(a, s)
get_data(a, f::Function) = f(a)

add_data(s, model, when::AbstractVector) = s ∈ when
add_data(s, model, when::Bool) = when
add_data(s, model, when) = when(model, s)

"""
    run!(model, agent_step! [, model_step!], n; kwargs...) → agent_df, model_df

Run the model (step it with the input arguments propagated into `step!`) and collect
data specified by the keywords, explained one by one below. Return the data as
two `DataFrame`s, one for agent-level data and one for model-level data.

## Data-deciding keywords
`agent_properties::Vector` decides the agent data. If an entry is a `name::Symbol`,
then the data for this entry is agent's field with that `name`. If an entry is a `f::Function`,
then the data for this entry is just `f(a)` for each agent `a`.

`model_properties::Vector` works exactly like `agent_properties` but for model level data.

`aggregation_dict` is a dictionary. #TODO: Describe what this is.

# TODO: Well, how do you use aggregation on entries of `agent_properties` that are
**functions**? Maybe it is better to make `aggregation_dict` keys to be integers,
that are the entries of `agent_properties`, instead of `symbols` that are only limited
to agent fields and not functions.

### Other keywords
* `collect0=true`: Whether to collect data at step zero, before running the model.
* `when=true` : at which steps `s` to perform the data collection and processing.
  A lot of flexibility is offered based on the type of `when`. If `when::Vector`,
  then data are collect if `s ∈ when`. Otherwise data are collected if `when(model, s)`
  returns `true`. By default data are collected in every step.
* `replicates=0` : Run `replicates` replicates of the simulation.
* `parallel=false` : Only when `replicates>0`. Run replicate simulations in parallel.
"""
function run! end

run!(model::ABM, agent_step!, n; kwargs...) =
run!(model::ABM, agent_step!, dummystep, n; kwargs...) =

function run!(model::ABM, agent_step!, model_step!, n;
    collect0::Bool=true, when=1:n, agent_properties=nothing, model_properties=nothing,
    aggregation_dict=nothing, replicates::Int=0, parallel::Bool=false
  )

  if replicates > 0
    if parallel
      dataall = parallel_replicates(model, agent_step!, model_step!, n, when; agent_properties=agent_properties, model_properties=model_properties, aggregation_dict=aggregation_dict, replicates=replicates)
    else
      dataall = series_replicates(model, agent_step!, model_step!, n, when; agent_properties=agent_properties, model_properties=model_properties, aggregation_dict=aggregation_dict, replicates=replicates)
    end
    return dataall
  else
    df = run!(model, agent_step!, model_step!, n; collect0=collect0, when=when, agent_properties=agent_properties, model_properties=model_properties, aggregation_dict=aggregation_dict)
    return df
  end
end

###################################################
# core data collection functions per step
###################################################
"""
    collect_agent_data(model::ABM, properties::Vector, step = 0) → df

Collect agent properties into a dataframe. `properties` can have symbols (fields) or
functions that take an agent as input and output a value. `step` is given only
so that the function adds the correct number in the `step` column.
"""
function collect_agent_data(model::ABM, properties::AbstractArray, step::Int = 0)
  dd = DataFrame()
  dd[!, :id] = collect(keys(model.agents))
  for fn in properties
    dd[!, fn] = get_data.(values(model.agents), fn)
  end
  dd[!, :step] = fill(step, size(dd, 1))
  return dd
end

collect_agent_data(model::ABM, properties::Nothing, step::Int=0) = DataFrame()

"""
    collect_model_data(model::ABM, properties::Vector, step = 0) → df

Same as [`collect_agent_data`](@ref) but for model data instead.
"""
function collect_model_data(model::ABM, properties::AbstractArray, step::Int = 0)
  dd = DataFrame()
  for fn in properties
    r =  get_data(model, fn)
    dd[!, Symbol(fn)] = [r]
  end
  dd[!, :step] = fill(step, size(dd, 1))
  return dd
end

collect_model_data(model::ABM, properties::Nothing, step::Int=0) = DataFrame()

"""
    aggregate_data(df::AbstractDataFrame, aggregation_dict::Dict)

Aggregate `df` columns  with some function(s) specified in `aggregation_dict`.
Each key in `aggregation_dict` is a column name (Symbol), and each value is
an array of function to aggregate that column.

Aggregation occurs per step.
"""
function aggregate_data(df::AbstractDataFrame, aggregation_dict::Dict)
  all_keys = collect(keys(aggregation_dict))
  dfnames = names(df)
  available_keys = [k for k in all_keys if in(k, dfnames)]
  length(available_keys) == 0 && return
  v1 = aggregation_dict[available_keys[1]]
  final_df = by(df, :step,  available_keys[1] => v1[1])
  for v2 in v1[2:end]
    dd = by(df, :step,  available_keys[1] => v2)
    final_df = join(final_df, dd, on=:step)
  end
  for k in available_keys[2:end]
    v = aggregation_dict[k]
    for v2 in v
      dd = by(df, :step,  k => v2)
      final_df = join(final_df, dd, on=:step)
    end
  end

  # rename columns
  colnames = Array{Symbol}(undef, size(final_df, 2))
  colnames[1] = :step
  counter = 2
  for k in available_keys
    v = aggregation_dict[k]
    for vv in v
      colnames[counter] = Symbol(join([vv,"(", string(k), ")"], ""))
      counter += 1
    end
  end
  rename!(final_df, colnames)

  return final_df
end

"used in _run!"
function collect_agent_data!(df::DataFrame, model::ABM, agent_properties,  aggregation_dict, step::Int)
  dft = collect_agent_data(model, agent_properties, step)
  if isnothing(aggregation_dict)
    df = vcat(df, dft)
  else
    dfa = aggregate_data(dft, aggregation_dict)
    df = vcat(df, dfa)
  end
  return df
end

"used in _run!"
function collect_model_data!(df::DataFrame, model::ABM, model_properties,  aggregation_dict, step::Int)
  dft = collect_model_data(model, model_properties, step)
  if isnothing(aggregation_dict)
    df = vcat(df, dft)
  else
    dfa = aggregate_data(dft, aggregation_dict)
    df = vcat(df, dfa)
  end
  return df
end

###################################################
# Core data collection loop
###################################################

"""
  _run!(args...)
Core function that loops over stepping a model and collecting data at each step.
"""
function _run!(
    model, agent_step!, model_step!, n;
    collect0 = true, when = true,
    model_properties=nothing, aggregation_dict=nothing, agent_properties=nothing,
  )

  if collect0
    df_model = collect_model_data(model, model_properties)
    df_agent = collect_agent_data(model, agent_properties)
    collect_agent_data!(df_agent, model, agent_properties, aggregation_dict, 0)
    collect_model_data!(df_model, model, model_properties, aggregation_dict, 0)
  else
    df_agent = DataFrame()
    df_model = DataFrame()
  end

  s = 0
  while until(s, n, model)
    step!(model, agent_step!, model_step!, 1)
    if add_data(s, model, when)
      df_model = collect_model_data!(df_model, model, model_properties, aggregation_dict, s)
      df_agent = collect_agent_data!(df_agent, model, agent_properties, aggregation_dict, s)
    end
    s += 1
  end
  return df_agent, df_model
end

###################################################
# Parallel / replicates
###################################################
"Run replicates of the same simulation"
function series_replicates(model, agent_step!, model_step!, n, when;
  model_properties=nothing, aggregation_dict=nothing, agent_properties=nothing, replicates=1)

  dataall = _run!(deepcopy(model), agent_step!, model_step!, n, when, model_properties=model_properties, aggregation_dict=aggregation_dict, agent_properties=agent_properties)
  dataall[!, :replicate] = [1 for i in 1:size(dataall, 1)]

  for rep in 2:replicates
    data = _run!(deepcopy(model), agent_step!, model_step!, n, when, model_properties=model_properties, aggregation_dict=aggregation_dict, agent_properties=agent_properties)
    data[!, :replicate] = [rep for i in 1:size(data, 1)]

    dataall = vcat(dataall, data)
  end
  return dataall
end

"""
A function to be used in `pmap` in `parallel_replicates`. It runs the `step!` function, but has a `dummyvar` parameter that does nothing, but is required for the `pmap` function.
"""
function parallel_step_dummy!(model::ABM, agent_step!, model_step!, n, when;
   model_properties=nothing, aggregation_dict=nothing, agent_properties=nothing, dummyvar=0)
  data = _run!(deepcopy(model), agent_step!, model_step!, n, when, model_properties=model_properties, aggregation_dict=aggregation_dict, agent_properties=agent_properties)
  return data
end

"""
    parallel_replicates(agent_step!, model::ABM, n, agent_properties::Array{Symbol}, when::AbstractArray{Integer}, replicates::Integer)

Runs `replicates` number of simulations in parallel and returns a `DataFrame`.
"""
function parallel_replicates(model::ABM, agent_step!, model_step!, n, when;
  model_properties=nothing, aggregation_dict=nothing, agent_properties=nothing, replicates=1)

  all_data = pmap(j-> parallel_step_dummy!(model, agent_step!, model_step!, n, when;
   model_properties=model_properties, aggregation_dict=aggregation_dict, agent_properties=agent_positions, dummyvar=j), 1:replicates)

  dd = DataFrame()
  for (rep, d) in enumerate(all_data)
    d[!, :replicate] = [rep for i in 1:size(d, 1)]
    dd = vcat(dd, d)
  end

  return dd
end

###################################################
# Parameter scanning
###################################################
"""
    paramscan(parameters, initialize; kwargs...)

Run the model with all the parameter value combinations given in `parameters`,
while initializing the model with `initialize`.
This function uses `DrWatson`'s [`dict_list`](https://juliadynamics.github.io/DrWatson.jl/dev/run&list/#DrWatson.dict_list)
internally. This means that every entry of `parameters` that is a `Vector`,
contains many parameters and thus is scanned. All other entries of
`parameters` that are not `Vector`s are not expanded in the scan.

`initialize` is a function that creates an ABM. It should accept keyword arguments.

### Keywords
All the following keywords are propagated into [`step!`](@ref):
`agent_step!, properties, n, when = 1:n, model_step! = dummystep`,
`step0::Bool = true`, `parallel::Bool = false`, `replicates::Int = 0`.

The following keywords modify the `paramscan` function:

`include_constants::Bool=false` determines whether constant parameters should be
included in the output `DataFrame`.

`progress::Bool = true` whether to show the progress of simulations.
"""
function paramscan(parameters::Dict, initialize;
  agent_step!, properties, n,
  when = 1:n,
  model_step! = dummystep,
  include_constants::Bool = false,
  replicates::Int = 0,
  progress::Bool = true,
  parallel::Bool = false
  )

  params = dict_list(parameters)
  if include_constants
    changing_params = keys(parameters)
  else
    changing_params = [k for (k, v) in parameters if typeof(v)<:Vector]
  end

  alldata = DataFrame()
  combs = dict_list(parameters)
  ncombs = length(combs)
  counter = 0
  for d in combs
    model = initialize(; d...)
    data = step!(model, agent_step!, model_step!, n, properties, when=when, replicates=replicates, parallel=parallel)  # TODO
    addparams!(data, d, changing_params)
    alldata = vcat(data, alldata)
    if progress
      # show progress
      counter += 1
      print("\u1b[1G")
      percent = round(counter*100/ncombs, digits=2)
      print("Progress: $percent%")
      print("\u1b[K")
    end
  end
  println()
  return alldata
end

"""
Adds new columns for each parameter in `changing_params`.
"""
function addparams!(df::AbstractDataFrame, params::Dict, changing_params)
  nrows = size(df, 1)
  for c in changing_params
    df[!, c] = [params[c] for i in 1:nrows]
  end
end

# This function is taken from DrWatson:
function dict_list(c::Dict)
    iterable_fields = filter(k -> typeof(c[k]) <: Vector, keys(c))
    non_iterables = setdiff(keys(c), iterable_fields)

    iterable_dict = Dict(iterable_fields .=> getindex.(Ref(c), iterable_fields))
    non_iterable_dict = Dict(non_iterables .=> getindex.(Ref(c), non_iterables))

    vec(
        map(Iterators.product(values(iterable_dict)...)) do vals
            dd = Dict(keys(iterable_dict) .=> vals)
            if isempty(non_iterable_dict)
                dd
            elseif isempty(iterable_dict)
                non_iterable_dict
            else
                merge(non_iterable_dict, dd)
            end
        end
    )
end

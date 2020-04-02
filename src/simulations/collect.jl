###################################################
# Definition of the data collection API
###################################################
get_data(a, s::Symbol) = getproperty(a, s)
get_data(a, f::Function) = f(a)

should_we_collect(s, model, when::AbstractVector) = s ∈ when
should_we_collect(s, model, when::Bool) = when
should_we_collect(s, model, when) = when(model, s)

"""
    run!(model, agent_step! [, model_step!], n; kwargs...) → agent_df, model_df

Run the model (step it with the input arguments propagated into `step!`) and collect
data specified by the keywords, explained one by one below. Return the data as
two `DataFrame`s, one for agent-level data and one for model-level data.

## Data-deciding keywords
* `agent_properties::Vector` decides the agent data. If an entry is a `Symbol`, e.g. `:weight`,
  then the data for this entry is agent's field `weight`. If an entry is a `Function`, e.g.
  `f`, then the data for this entry is just `f(a)` for each agent `a`.
  The resulting dataframe colums are named with the input symbol (here `:weight, :f`).

* `model_properties::Vector` works exactly like `agent_properties` but for model level data.

# TODO: add dict example
* `aggregation_dict` decides whether the agent data should be aggregated over
  agents. Each key in `aggregation_dict` is a column name (`Symbol`), and each
  value is an array of functions to aggregate that column. You can't use aggregation
  with function name that coincides with field name (`:weight` vs `weight(a)`).
  You must provide `agent_properties` for aggregation, because it is impossible
  to know whether the symbol `:weight` comes from the agent field `weight` or the
  function `weight`.

By default all of the above keywords are `nothing`, i.e. nothing is collected/aggregated.

### Other keywords
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
  when=1:n, agent_properties=nothing, model_properties=nothing,
  aggregation_dict=nothing, replicates::Int=0, parallel::Bool=false
  )

  if replicates > 0
    if parallel
      # TODO: Use keyword propagation and reduce duplication of all these keyword arguments
      dataall = parallel_replicates(model, agent_step!, model_step!, n, when;
      agent_properties=agent_properties, model_properties=model_properties, aggregation_dict=aggregation_dict, replicates=replicates)
    else
      dataall = series_replicates(model, agent_step!, model_step!, n, when;
      agent_properties=agent_properties, model_properties=model_properties, aggregation_dict=aggregation_dict, replicates=replicates)
    end
    return dataall
  else
    df = run!(model, agent_step!, model_step!, n;
    when=when, agent_properties=agent_properties,
    model_properties=model_properties, aggregation_dict=aggregation_dict)
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

## Example

A `model` has 10 agents, each with a `wealth::Float64` field. Agents are scattered
on a `GridSpace((10,10))`. To obtain the current wealth of all agents, and their
x-position on the grid:

```julia
x_position(agent) = first(agent.pos)
data = collect_agent_data(model, [:wealth, x_position], 1)
```

Notice we used a `Symbol` to directly obtain the `wealth` value for each agent, and
a function call to find the x-position.

To obtain the average wealth from this data, one can use `mean(data[!, :wealth)`.
"""
function collect_agent_data(model::ABM, properties::AbstractArray, step::Int = 0)
  dd = DataFrame()
  dd[!, :id] = collect(keys(model.agents))
  for fn in properties
    dd[!, Symbol(fn)] = get_data.(values(model.agents), fn)
  end
  dd[!, :step] = fill(step, size(dd, 1))
  return dd
end

"""
    collect_agent_data(model::ABM, properties::Dict, step = 0) → df

Collect aggregate properties pertaining to all agents into a dataframe.
This option is useful if aggregate data is the only information that's needed
to be recovered from the agents in the model. If data from individual agents
is required along-side aggregate results, it is better to use the `properties::Vector`
form of this method, then post process the result.

`properties` should take one of two forms.
- `Dict{Symbol,Array{Function,1}}`: where the key `Symbol` relates to an existing
agent field
- `Dict{Function,Array{Function,1}}`: where the key is a function that obtains the value
which is to be aggregated. The name of the function will be the name associated with the
resultant column in the DataFrame.

`step` is given only so that the function adds the correct number in the `step` column.

## Example

A `model` has 10 agents, each with a `wealth::Float64` field. Agents are scattered
on a `GridSpace((10,10))`. To obtain the average wealth of all agents:

```julia
data = collect_agent_data(model, Dict(:wealth => [mean]), 1)
```

To find the average x-position of the agents on the grid:
```julia
x_position(agent) = first(agent.pos)
data = collect_agent_data(model, Dict(x_position => [mean]), 1)
```
"""
collect_agent_data(model::ABM, properties::Dict, step::Int=0) =

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
  if aggregation_dict == nothing
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

  df_agent = DataFrame()
  df_model = DataFrame()

  s = 0
  while until(s, n, model)
    if should_we_collect(s, model, when)
      dfm = collect_model_data(model, model_properties, s)
      df_model = vcat(df_model, dfm)
      df_agent = collect_agent_data!(df_agent, model, agent_properties, aggregation_dict, s)
    end
    step!(model, agent_step!, model_step!, 1)
    s += 1
  end
  return df_agent, df_model
end

###################################################
# Parallel / replicates
###################################################
function replicateCol!(df, rep)
  df[!, :replicate] = [rep for i in 1:size(df, 1)]
end

"Run replicates of the same simulation"
function series_replicates(model, agent_step!, model_step!, n, when;
  model_properties=nothing, aggregation_dict=nothing, agent_properties=nothing, replicates=1)

  df_agent, df_model = _run!(deepcopy(model), agent_step!, model_step!, n, when, model_properties=model_properties, aggregation_dict=aggregation_dict, agent_properties=agent_properties)
  replicateCol!(df_agent, 1)
  replicateCol!(df_model, 1)

  for rep in 2:replicates
    df_agentTemp, df_modelTemp = _run!(deepcopy(model), agent_step!, model_step!, n, when, model_properties=model_properties, aggregation_dict=aggregation_dict, agent_properties=agent_properties)
    replicateCol!(df_agentTemp, rep)
    replicateCol!(df_modelTemp, rep)

    df_agent = vcat(df_agent, df_agentTemp)
    df_model = vcat(df_model, df_modelTemp)
  end
  return df_agent, df_model
end

"""
A function to be used in `pmap` in `parallel_replicates`. It runs the `_run!` function, but has a `dummyvar` parameter that does nothing, but is required for the `pmap` function.
"""
function parallel_step_dummy!(model::ABM, agent_step!, model_step!, n, when;
   model_properties=nothing, aggregation_dict=nothing, agent_properties=nothing, dummyvar=0)
  df_agent, df_model = _run!(deepcopy(model), agent_step!, model_step!, n, when, model_properties=model_properties, aggregation_dict=aggregation_dict, agent_properties=agent_properties)
  return (df_agent, df_model)
end

"""
    parallel_replicates(agent_step!, model::ABM, n, agent_properties::Array{Symbol}, when::AbstractArray{Integer}, replicates::Integer)

Runs `replicates` number of simulations in parallel and returns a `DataFrame`.
"""
function parallel_replicates(model::ABM, agent_step!, model_step!, n, when;
  model_properties=nothing, aggregation_dict=nothing, agent_properties=nothing, replicates=1)

  all_data = pmap(j-> parallel_step_dummy!(model, agent_step!, model_step!, n, when;
   model_properties=model_properties, aggregation_dict=aggregation_dict,
   agent_properties=agent_positions, dummyvar=j), 1:replicates)

  df_agent = DataFrame()
  df_model = DataFrame()
  for (rep, d) in enumerate(all_data)
    replicateCol!(d[1], rep)
    replicateCol!(d[2], rep)
    df_agent = vcat(df_agent, d[1])
    df_model = vcat(df_model, d[2])
  end

  return df_agent, df_model
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
  agent_step!, n,
  when = 1:n,
  agent_properties=nothing,
  model_properties=nothing,
  aggregation_dict=nothing,
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

  df_agent, df_model = DataFrame(), DataFrame()
  combs = dict_list(parameters)
  ncombs = length(combs)
  counter = 0
  for d in combs
    model = initialize(; d...)
    df_agentTemp, df_modelTemp = run!(model, agent_step!, model_step!, n;
    when=when, agent_properties=agent_properties, model_properties=model_properties,
    aggregation_dict=aggregation_dict, replicates=replicates, parallel=parallel)
    addparams!(df_agent, d, changing_params)  # TODO not all params are for agent/model df
    addparams!(df_model, d, changing_params)
    df_agent = vcat(df_agent, df_agentTemp)
    df_model = vcat(df_model, df_modelTemp)
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
  return df_agent, df_model
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

export run!, collect_agent_data!, collect_model_data!,
       init_agent_dataframe, init_model_dataframe

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
run!(model::ABM, agent_step!, dummystep, n; kwargs...)

function run!(model::ABM, agent_step!, model_step!, n;
  replicates::Int=0, parallel::Bool=false, kwargs...)

  r = replicates
  if r > 0
    if parallel
      dataall = parallel_replicates(model, agent_step!, model_step!, n, r; kwargs...)
    else
      dataall = series_replicates(model, agent_step!, model_step!, n, r; kwargs...)
    end
    return dataall
  else
    df = _run!(model, agent_step!, model_step!, n; kwargs...)
    return df
  end
end

###################################################
# Core data collection loop
###################################################
"""
  _run!(model, agent_step!, model_step!, n; kwargs...)
Core function that loops over stepping a model and collecting data at each step.
"""
function _run!(model, agent_step!, model_step!, n;
               when = true, model_properties=nothing, agent_properties=nothing)

  df_agent = init_agent_dataframe(model, agent_properties)
  df_model = init_model_dataframe(model, model_properties)

  s = 0
  while until(s, n, model)
    if should_we_collect(s, model, when)
      collect_agent_data!(df_agent, model, agent_properties, s)
      collect_model_data!(df_model, model, model_properties, s)
    end
    step!(model, agent_step!, model_step!, 1)
    s += 1
  end
  return df_agent, df_model
end

###################################################
# core data collection functions per step
###################################################
# TODO: Add (minimal) docstrings into all exported functions (4 of them)
function init_agent_dataframe(model::ABM, properties::AbstractArray)
    headers = Array{Symbol,1}(undef, 2+length(properties))
    headers[1] = :id
    headers[2:end-1] .= [Symbol(k) for k in properties]
    headers[end] = :step

    types = Array{Array,1}(undef, 2+length(properties))
    types[1] = Int[]
    types[end] = Int[]
    for (i,k) in enumerate(properties)
        #TODO: if/else assumes Symbol or function. Don't think we've checked that anywhere yet
        #TODO: we need at least one agent in the model to confirm the resultant type.
        #      this should probably be checked before this time.
        #NOTE: if we enforce `x_pos(agent)::Int = ...`, then Base.return_types could be invoked
        #without having to worry about getting an instance of the function.
        types[i+1] = typeof(k) <: Symbol ? fieldtype(Agents.agenttype(model), k)[] :
                                           typeof(k(values(model.agents[1])))[]
    end
    DataFrame(types, headers)
end

#TODO: implement
init_agent_dataframe(model::ABM, properties::Dict) = DataFrame()
init_agent_dataframe(model::ABM, properties::Nothing) = DataFrame()

function init_model_dataframe(model::ABM, properties::AbstractArray)
    headers = Array{Symbol,1}(undef, 1+length(properties))
    headers[1:end-1] .= [Symbol(k) for k in properties]
    headers[end] = :step

    types = Array{Array,1}(undef, 1+length(properties))
    types[end] = Int[]
    for (i,k) in enumerate(properties)
        #TODO: if/else assumes Symbol or function. Don't think we've checked that anywhere yet
        #TODO: assumes property is extant in the list
        types[i] = typeof(k) <: Symbol ? typeof(model.properties[k])[] :
                                         typeof(k(model))[]
    end
    DataFrame(types, headers)
end

init_model_dataframe(model::ABM, properties::Nothing) = DataFrame()

function collect_agent_data!(df::AbstractDataFrame, model::ABM, properties::AbstractArray, step::Int=0)
  dd = collect_agent_data(model, properties, step)
  append!(df, dd)
end

#TODO: implement aggergation properly
collect_agent_data!(df::AbstractDataFrame, model::ABM, properties::Dict, step::Int=0) = DataFrame()
collect_agent_data!(df::AbstractDataFrame, model::ABM, properties::Nothing, step::Int=0) = DataFrame()


###################################################
# OLD DATA COLLECTION FUNCTIONS
###################################################
# TODO: DELETE THESE

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

function collect_model_data!(df::AbstractDataFrame, model::ABM, properties::AbstractArray, step::Int=0)
  dd = collect_model_data(model, properties, step)
  append!(df, dd)
end

collect_model_data!(df::AbstractDataFrame, model::ABM, properties::Nothing, step::Int=0) = DataFrame()
"""
    aggregate_data(df::AbstractDataFrame, aggregation_dict::Dict)

Aggregate `df` columns with some function(s) specified in `aggregation_dict`.
Each key in `aggregation_dict` can be a `Symbol`, which is converted to a column name, and
each value is an array of function to aggregate that column.
Additionally, the key can be a function that obtains the value which is to be aggregated.
The name of the function will be the name associated with the resultant column in the
DataFrame.

Aggregation occurs per step.
"""
function aggregate_data(df::AbstractDataFrame, aggregation_dict::Dict)
  all_keys = collect(keys(aggregation_dict))
  dfnames = names(df)
  available_keys = [k for k in all_keys if in(Symbol(k), dfnames)]
  length(available_keys) == 0 && return
  v1 = aggregation_dict[available_keys[1]]
  final_df = by(df, :step, Symbol(available_keys[1]) => v1[1])
  for v2 in v1[2:end]
    dd = by(df, :step, Symbol(available_keys[1]) => v2)
    final_df = join(final_df, dd, on=:step)
  end
  for k in available_keys[2:end]
    v = aggregation_dict[k]
    for v2 in v
      dd = by(df, :step,  Symbol(k) => v2)
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

###################################################
# Parallel / replicates
###################################################
function replicate_col!(df, rep)
  df[!, :replicate] = [rep for i in 1:size(df, 1)]
end

"Run replicates of the same simulation"
function series_replicates(model, agent_step!, model_step!, n, replicates; kwargs...)

  df_agent, df_model = _run!(deepcopy(model), agent_step!, model_step!, n; kwargs...)
  replicate_col!(df_agent, 1)
  replicate_col!(df_model, 1)

  for rep in 2:replicates
    df_agentTemp, df_modelTemp = _run!(deepcopy(model), agent_step!, model_step!, n; kwargs...)
    replicate_col!(df_agentTemp, rep)
    replicate_col!(df_modelTemp, rep)

    append!(df_agent, df_agentTemp)
    append!(df_model, df_modelTemp)
  end
  return df_agent, df_model
end

"Run replicates of the same simulation in parallel"
function parallel_replicates(model::ABM, agent_step!, model_step!, n, replicates; kwargs...)

  all_data = pmap(j -> _run!(deepcopy(model), agent_step!, model_step!, n; kwargs...),
                  1:replicates)

  df_agent = DataFrame()
  df_model = DataFrame()
  for (rep, d) in enumerate(all_data)
    replicate_col!(d[1], rep)
    replicate_col!(d[2], rep)
    append!(df_agent, d[1])
    append!(df_model, d[2])
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
  agent_step!, n,  model_step! = dummystep,
  progress::Bool = true,
  include_constants::Bool = false,
  kwargs...
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
    df_agentTemp, df_modelTemp = run!(model, agent_step!, model_step!, n; kwargs...)
    # TODO not all params are for agent/model df
    addparams!(df_agent, d, changing_params)
    addparams!(df_model, d, changing_params)
    append!(df_agent, df_agentTemp)
    append!(df_model, df_modelTemp)
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

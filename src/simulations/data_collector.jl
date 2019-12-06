export paramscan

"""
    data_collecter_aggregate(model::ABM, field_aggregator::Dict; step=1)

`field_aggregator` is a dictionary whose keys are field names of agents (they should be symbols) and whose values are aggregator functions to be applied to those fields. For example, if your agents have a field called `wealth`, and you want to calculate mean and median population wealth, your `field_aggregator` dict will be `Dict(:wealth => [mean, median])`.

If an agent field returns an array instead of a single number, the mean of that array will be calculated before the aggregator functions are applied to them.

To apply a function to the list of agents, use `:agent` as a dictionary key.

To apply a function to the model object, use `:model` as a dictionary key.

Returns two arrays: the first one is the values of applying aggregator functions to the fields, and the second one is a header column for the first array.
"""
function data_collecter_aggregate(model::ABM, field_aggregator::Dict; step=1)
  ncols = 1
  colnames = ["step"]
  for (k,v) in field_aggregator
    ncols += length(v)
    for vv in v
      push!(colnames, join([vv,"(", string(k), ")"], ""))
    end
  end
  output = Array{Any}(undef, ncols)
  output[1] = step
  agent_ids = keys(model.agents)
  counter = 2
  rand_agent_id = 0
  for aa in agent_ids
    rand_agent_id = aa
    break
  end
  for (fn, aggs) in field_aggregator
    if fn == :agent
      temparray = values(model.agents)
    elseif fn == :model
      temparray = model
    elseif typeof(getproperty(model.agents[rand_agent_id], fn)) <: AbstractArray
      temparray = [mean(getproperty(model.agents[i], fn)) for i in agent_ids]
    else
      temparray = [getproperty(model.agents[i], fn) for i in agent_ids]
    end
    for agg in aggs
      output[counter] = agg(temparray)
      counter += 1
    end
  end
  return output, colnames
end

"""
    data_collecter_raw( model::ABM, properties::Array{Symbol})

Collects agent properties (fields of the agent object) into a dataframe.

If  an agent field returns an array, the mean of those arrays will be recorded.

"""
function data_collecter_raw(model::ABM, properties::Array{Symbol}; step=1)
  dd = DataFrame()
  agent_ids = keys(model.agents)
  counter = 2
  rand_agent_id = 0
  for aa in agent_ids
    rand_agent_id = aa
    break
  end
  agentslen = nagents(model)
  for fn in properties
    if typeof(getproperty(model.agents[rand_agent_id], fn)) <: AbstractArray
      temparray = [mean(getproperty(model.agents[i], fn)) for i in agent_ids]
    else
      temparray = [getproperty(model.agents[i], fn) for i in agent_ids]
    end
    begin
      dd[!, :id] = sort(collect(keys(model.agents)))
    end
    fieldname = fn
    begin
      dd[!, fieldname] = temparray
    end
  end
  dd[!, :step] = [step for i in 1:size(dd, 1)]
  return dd
end

"""
    data_collector(model::ABM, field_aggregator::Dict, step::Integer [, df::DataFrame]) where T<: Integer

Used in the `step!` function.

Returns a DataFrame of collected data. If `df` is supplied, appends to collected data to it.
"""
function data_collector(model::ABM, field_aggregator::Dict, step::Integer) where T<: Integer
  d, colnames = data_collecter_aggregate(model, field_aggregator, step=step)
  dict = Dict(Symbol(colnames[i]) => d[i] for i in 1:length(d))
  df = DataFrame(dict)
  return df
end

function data_collector(model::ABM, field_aggregator::Dict, step::Integer, df::DataFrame) where T<:Integer
  d, colnames = data_collecter_aggregate(model, field_aggregator, step=step)
  dict = Dict(Symbol(colnames[i]) => d[i] for i in 1:length(d))
  push!(df, dict)
  return df
end

"""
    data_collector(model::ABM, properties::Array{Symbol}, step::Integer [, df::DataFrame]) where T<:Integer

Used in the `step!` function.

Returns a DataFrame of collected data. If `df` is supplied, appends to collected data to it.
"""
function data_collector(model::ABM, properties::Array{Symbol}, step::Integer) where T<:Integer
  df = data_collecter_raw(model, properties, step=step)
  return df
end

function data_collector(model::ABM, properties::Array{Symbol}, step::Integer, df::DataFrame) where T<:Integer
  d = data_collecter_raw(model, properties, step=step)
  df = vcat(df, d) #join(df, d, on=:id, kind=:outer)
  return df
end

function _step(model, agent_step!, model_step!, properties, when, n, step0)
  if step0
    df = data_collector(model, properties, 0)
  else
    df = data_collector(model, properties, 0)
    colnames = names(df)
    coltypes = [eltype(df[!, i]) for i in colnames]
    df = DataFrame(coltypes, colnames)
  end
  for ss in 1:n
    step!(model, agent_step!, model_step!)
    # collect data
    if ss in when
      df = data_collector(model, properties, ss, df)
    end
  end
  return df
end

function series_replicates(model, agent_step!, model_step!, properties, when, n, replicates, step0)

  dataall = _step(deepcopy(model), agent_step!, model_step!, properties, when, n, step0)
  dataall[!, :replicate] = [1 for i in 1:size(dataall, 1)]

  for rep in 2:replicates
    data = _step(deepcopy(model), agent_step!, model_step!, properties, when, n, step0)
    data[!, :replicate] = [rep for i in 1:size(data, 1)]

    dataall = vcat(dataall, data)
  end
  return dataall
end


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
  step0::Bool = true,
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
    data = step!(model, agent_step!, model_step!, n, properties, when=when, replicates=replicates, step0=step0, parallel=parallel)
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

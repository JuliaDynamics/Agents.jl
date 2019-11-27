export combine_columns!, gridsearch

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
    if fn == :pos && typeof(model.agents[rand_agent_id].pos) <: Tuple
      temparray = [coord2vertex(model.agents[i], model) for i in agent_ids]
    elseif fn == :agent
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
    if fn == :pos  && typeof(model.agents[rand_agent_id].pos) <: Tuple
      temparray = [coord2vertex(model.agents[i], model) for i in agent_ids]
    elseif typeof(getproperty(model.agents[rand_agent_id], fn)) <: AbstractArray
      temparray = [mean(getproperty(model.agents[i], fn)) for i in agent_ids]
    else
      temparray = [getproperty(model.agents[i], fn) for i in agent_ids]
    end
    begin
      dd[!, :id] = sort(collect(keys(model.agents)))
    end
    fieldname = Symbol(join([string(fn), step], "_"))
    begin
      dd[!, fieldname] = temparray
    end
  end
  return dd
end

"""
    data_collector(model::ABM, field_aggregator::Dict, when::AbstractArray{T}, step::Integer [, df::DataFrame]) where T<: Integer

Used in the `step!` function.

Returns a DataFrame of collected data. If `df` is supplied, appends to collected data to it.
"""
function data_collector(model::ABM, field_aggregator::Dict, when::AbstractArray{T}, step::Integer) where T<: Integer
  d, colnames = data_collecter_aggregate(model, field_aggregator, step=step)
  dict = Dict(Symbol(colnames[i]) => d[i] for i in 1:length(d))
  df = DataFrame(dict)
  return df
end

function data_collector(model::ABM, field_aggregator::Dict, when::AbstractArray{T}, step::Integer, df::DataFrame) where T<:Integer
  d, colnames = data_collecter_aggregate(model, field_aggregator, step=step)
  dict = Dict(Symbol(colnames[i]) => d[i] for i in 1:length(d))
  push!(df, dict)
  return df
end

"""
    data_collector(model::ABM, properties::Array{Symbol}, when::AbstractArray{T}, step::Integer [, df::DataFrame]) where T<:Integer

Used in the `step!` function.

Returns a DataFrame of collected data. If `df` is supplied, appends to collected data to it.
"""
function data_collector(model::ABM, properties::Array{Symbol}, when::AbstractArray{T}, step::Integer) where T<:Integer
  df = data_collecter_raw(model, properties, step=step)
  return df
end

function data_collector(model::ABM, properties::Array{Symbol}, when::AbstractArray{T}, step::Integer, df::DataFrame) where T<:Integer
  d = data_collecter_raw(model, properties, step=step)
  df = join(df, d, on=:id, kind=:outer)
  return df
end

"""
    combine_columns(data::DataFrame, column_names::Array{Symbol}, aggregator::AbstractVector)

Combines columns of the data that contain the same type of info from different steps of the model into one column using an aggregator, e.g. mean. You should either supply all column names that contain the same type of data, or one name (as a string) that precedes a number in different columns, e.g. "pos_"{some number}.
"""
function combine_columns!(data::DataFrame, column_names::Array{Symbol}, aggregators::AbstractVector)
  for ag in aggregators
    d = by(data, :step, column_names => x-> (ag([getproperty(x, i) for i in column_names])))
    colname = Symbol(string(column_names[1])[1:end-1] * string(ag))
    data[!, colname] = d[!, names(d)[end]]
  end
  return data
end

function combine_columns!(data::DataFrame, column_base_name::String, aggregators::AbstractVector)
  column_names = vcat([column_base_name], [column_base_name*"_"*string(i) for i in 1:size(data, 2)])
  datanames = [string(i) for i in names(data)]
  final_names = Array{Symbol}(undef, 0)
  for cn in column_names
    if cn in datanames
      push!(final_names, Symbol(cn))
    end
  end
  combine_columns!(data, final_names, aggregators)
end

function _step(model, agent_step!, model_step!, properties, when, n)
  df = data_collector(model, properties, when, 0)
  for ss in 1:n
    step!(model, agent_step!, model_step!)
    # collect data
    if ss in when
      df = data_collector(model, properties, when, ss, df)
    end
  end
  return df
end

function series_replicates(model, agent_step!, model_step!, properties, when, n, single_df, replicates)
  if single_df
    dataall = _step(deepcopy(model), agent_step!, model_step!, properties, when, n)
  else
    dataall = [_step(deepcopy(model), agent_step!, model_step!, properties, when, n)]
  end
  for i in 2:replicates
    data = _step(deepcopy(model), agent_step!, model_step!, properties, when, n)
    if single_df
      dataall = join(dataall, data, on=:step, kind=:outer, makeunique=true)
    else
      push!(dataall, data)
    end
  end
  return dataall
end


"""
    gridsearch(;param_ranges::Dict, model_properties::Dict, n::Int,
  collect_fields::Dict, when::AbstractArray, model_initiation, agent_step, model_step)

Runs the model with all the parameter value combinations given in `param_ranges`.
`param_ranges` is a dictionary that maps parameter names (symbol) to parameter
ranges.

`model_properties` is a dictionary that includes all the items to be passed as 
`properties` to the `ABM` object, and also any arguments that are passed to a function
that builds the model object.

`model_initiation` is a function that accepts one argument which is a dictionary 
(`model_properties`).

`collect_fields` is the same dictionary used in the `step!` function that determines
what information should be collected. Here, it should only be a dictionary.

Running replicates is not implemented yet. 

"""
function gridsearch(;param_ranges::Dict, model_properties::Dict, n::Int,
  collect_fields::Dict, when::AbstractArray, model_initiation, agent_step, model_step)

  pvalues, pnames = combinations(param_ranges)

  comb = 1
  for p in 1:length(pnames)
    model_properties[pnames[p]] = pvalues[comb][p]
  end
  model = model_initiation(model_properties)
  data = step!(model, agent_step, model_step, n, collect_fields,
  when=when)
  nrows = size(data, 1)
  for p in 1:length(pnames)
    data[!, pnames[p]] = [pvalues[comb][p] for i in 1:nrows]
  end

  for comb in 2:length(pvalues)
    for p in 1:length(pnames)
      model_properties[pnames[p]] = pvalues[comb][p]
    end
    model = model_initiation(model_properties)
    d = step!(model, agent_step, model_step, n, collect_fields, when=when)
    nrows = size(d, 1)
    for p in 1:length(pnames)
      d[!, pnames[p]] = [pvalues[comb][p] for i in 1:nrows]
    end
    data = vcat(data, d)
  end

  return data
end


"""
  combinations(param_ranges::Dict)

Returns all parameter combinations with the ranges given in `param_ranges`.
`param_ranges` is a dictionary that maps parameter names (symbol) to parameter
ranges.
"""
function combinations(param_ranges::Dict)
  pnames = collect(keys(param_ranges))
  pranges = collect(values(param_ranges))
  nparams = length(pnames)
  if nparams <= 1
    return [i for i in pranges[1]], pnames
  end

  outorder = [pnames[1], pnames[2]]
  out = Array{Array}(undef, length(pranges[1]) * length(pranges[2]))
  counter = 1
  for l1 in pranges[1]
    for l2 in pranges[2]
      out[counter] = Any[l1, l2]
      counter += 1
    end
  end

  for param in 3:nparams
    out2 = Array{Array}(undef, length(out) * length(pranges[param]))
    counter = 1
    for l1 in out
      for l2 in pranges[param]
        out2[counter] = vcat(l1, l2)
        counter += 1
      end
    end
    out = out2
    push!(outorder, pnames[param])
  end

  return out, outorder
end

export combine_columns!, paramscan

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
    paramscan(;parameters::Dict, properties, when::AbstractArray, initialize, agent_step, model_step)

Runs the model with all the parameter value combinations given in `parameters`.
`parameters` is a dictionary that maps parameter names (symbol) to parameter
values. If you want to test a range of parameters, you should specify those ranges in a 
`Vector`.

`initialize` is a function that creates an ABM object. It should accepts keyword arguments.
It should have arguments for every key in the `parameters` dict, even if it does not use them..

`properties` is the same dictionary used in the `step!` function that determines
what information should be collected.

Running replicates is not implemented, yet.
"""
function paramscan(;parameters::Dict, properties, when::AbstractArray, initialize,
  agent_step, model_step)

  params = dict_list(parameters)
  changing_params = [k for (k, v) in parameters if typeof(v)<:Vector]

  alldata = DataFrame()
  for d in dict_list(parameters)
    model = initialize(; d...)
    data = step!(model, agent_step, model_step, parameters[:n], properties, when=when)
    addparams!(data, d, changing_params)
    alldata = vcat(data, alldata)
  end

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


"""
    dict_list(c::Dict)
Expand the dictionary `c` into a vector of dictionaries.
Each entry has a unique combination from the product of the `Vector`
values of the dictionary while the non-`Vector` values are kept constant
for all possibilities. The keys of the entries are the same.
Whether the values of `c` are iterable or not is of no concern;
the function considers as "iterable" only subtypes of `Vector`.
Use the function [`dict_list_count`](@ref) to get the number of
dictionaries that `dict_list` will produce.
## Examples
```julia
julia> c = Dict(:a => [1, 2], :b => 4);
julia> dict_list(c)
3-element Array{Dict{Symbol,Int64},1}:
 Dict(:a=>1,:b=>4)
 Dict(:a=>2,:b=>4)
julia> c[:model] = "linear"; c[:run] = ["bi", "tri"];
julia> dict_list(c)
4-element Array{Dict{Symbol,Any},1}:
 Dict(:a=>1,:b=>4,:run=>"bi",:model=>"linear")
 Dict(:a=>2,:b=>4,:run=>"bi",:model=>"linear")
 Dict(:a=>1,:b=>4,:run=>"tri",:model=>"linear")
 Dict(:a=>2,:b=>4,:run=>"tri",:model=>"linear")
julia> c[:e] = [[1, 2], [3, 5]];
julia> dict_list(c)
8-element Array{Dict{Symbol,Any},1}:
 Dict(:a=>1,:b=>4,:run=>"bi",:e=>[1, 2],:model=>"linear")
 Dict(:a=>2,:b=>4,:run=>"bi",:e=>[1, 2],:model=>"linear")
 Dict(:a=>1,:b=>4,:run=>"tri",:e=>[1, 2],:model=>"linear")
 Dict(:a=>2,:b=>4,:run=>"tri",:e=>[1, 2],:model=>"linear")
 Dict(:a=>1,:b=>4,:run=>"bi",:e=>[3, 5],:model=>"linear")
 Dict(:a=>2,:b=>4,:run=>"bi",:e=>[3, 5],:model=>"linear")
 Dict(:a=>1,:b=>4,:run=>"tri",:e=>[3, 5],:model=>"linear")
 Dict(:a=>2,:b=>4,:run=>"tri",:e=>[3, 5],:model=>"linear")
```
"""
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
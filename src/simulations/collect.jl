"""
Collects agent properties (fields of the agent object) into a dataframe.
"""
function collect_agent_data(model::ABM, properties::Array{Symbol}; step=1)
  dd = DataFrame()
  dd[!, :id] = collect(keys(model.agents))
  for fn in properties
    dd[!, fn] = getproperty.(values(model.agents), fn)
  end
  dd[!, :step] = repeat([step], size(dd, 1))
  return dd
end

"""
Collects agent properties (fields of the agent object) into a dataframe
and appends them to the supplied `df`.
"""
function collect_agent_data!(df::DataFrame, model::ABM, properties::Array{Symbol}; step::Integer)
  d = collect_agent_data(model, properties, step=step)
  df = vcat(df, d)
  return df
end

"""
Collects model properties from functions provided in `properties`.
"""
function collect_model_data(model::ABM, properties::AbstractArray; step=1)
  dd = DataFrame()
  for fn in properties
    r = fn(model)
    if typeof(r) <: AbstractArray
      d[!, Symbol(fn)] = r
    else 
      dd[!, Symbol(fn)] = [r]
    end
  end
  dd[!, :step] = repeat([step], size(dd, 1))
  return dd
end

# TODO: decide on the shape of model data. what if the output for each function has a different length?
"""
    aggregate_data(df::AbstractDataFrame, aggregation_dict::Dict)
  
Aggregate `df` columns  with some function(s) specified in `aggregation_dict`.
Each key in `aggregation_dict` is a column name (Symbol), and each value is
an array of function to aggregate that column.

Aggregation occurs per step.
"""
function aggregate_data(df::AbstractDataFrame, aggregation_dict::Dict)
  all_keys = collect(keys(aggregation_dict))
  v1 = aggregation_dict[all_keys[1]]
  final_df = by(df, :step,  all_keys[1] => v1[1])
  for v2 in v1[2:end]
    dd = by(df, :step,  k => v2)
    final_df = join(final_df, dd, on=:step)
  end
  for k in all_keys[2:end]
    v = aggregation_dict[k]
    for v2 in v
      dd = by(df, :step,  k => v2)
      final_df = join(final_df, all_df[di], on=:step)
    end
  end

  # rename columns
  colnames = Array{Symbol}(undef, length(final_df, 2)) 
  colnames[1] = :step
  counter = 2
  for (k,v) in aggregation_dict
    for vv in v
      colnames[counter] = Symbol(join([vv,"(", string(k), ")"], ""))
      counter += 1
    end
  end
  rename!(final_df, colnames)

  return final_df
end

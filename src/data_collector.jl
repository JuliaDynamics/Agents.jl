"""
    agents_data_per_step(properties::Array{Symbol}, aggregators::Array{Function})

Collect data from a `property` of agents (a `fieldname`) and apply `aggregators` function to them.

If a fieldname of agents returns an array, this will use the `mean` of the array on which to apply aggregators.

"""
function agents_data_per_step(properties::Array{Symbol}, aggregators::Array, model::AbstractModel; step=1)    
  output = Array{Real}(undef, length(properties) * length(aggregators) + 1)
  output[1] = step
  agentslen = nagents(model)
  counter = 2
  for fn in properties
    if fn == :pos
      temparray = [coord_to_vertex(model.agents[i], model) for i in 1:agentslen]
    elseif typeof(getproperty(model.agents[1], fn)) <: AbstractArray
      temparray = [mean(getproperty(model.agents[i], fn)) for i in 1:agentslen]
    else
      temparray = [getproperty(model.agents[i], fn) for i in 1:agentslen]
    end
    for agg in aggregators
      output[counter] = agg(temparray)
      counter += 1
    end
  end
  colnames = hcat(["step"], [join([string(i[1]), split(string(i[2]), ".")[end]], "_") for i in product(properties, aggregators)])
  return output, colnames
end


"""
    agents_data_complete(properties::Array{Symbol}, model::AbstractModel)

Collect data from a `property` of agents (a `fieldname`) into a dataframe.

If a fieldname of agents returns an array, this will use the `mean` of the array. If you want to record positions of the agents, use the `pos` field.
"""
function agents_data_complete(properties::Array{Symbol}, model::AbstractModel; step=1)
  # colnames = [join([string(i[1]), split(string(i[2]), ".")[end]], "_") for i in product(properties, aggregators)]
  dd = DataFrame()
  agentslen = nagents(model)
  for fn in properties
    if fn == :pos
      temparray = [coord_to_vertex(model.agents[i], model) for i in 1:agentslen]
    elseif typeof(getproperty(model.agents[1], fn)) <: AbstractArray
      temparray = [mean(getproperty(model.agents[i], fn)) for i in 1:agentslen]
    else
      temparray = [getproperty(model.agents[i], fn) for i in 1:agentslen]
    end
    dd[:id] = [i.id for i in model.agents]
    fieldname = Symbol(join([string(fn), step], "_"))
    dd[fieldname] = temparray
  end
  return dd
end

function data_collector(properties::Array{Symbol}, aggregators::Array{Function}, steps_to_collect_data::Array{Int64}, model::AbstractModel, step::Integer)
  d, colnames = agents_data_per_step(properties, aggregators, model, step=step)
  dict = Dict(Symbol(colnames[i]) => d[i] for i in 1:length(d))
  df = DataFrame(dict)
  return df
end

function data_collector(properties::Array{Symbol}, aggregators::Array{Function}, steps_to_collect_data::Array{Int64}, model::AbstractModel, step::Integer, df::DataFrame)
  d, colnames = agents_data_per_step(properties, aggregators, model, step=step)
  dict = Dict(Symbol(colnames[i]) => d[i] for i in 1:length(d))
  push!(df, dict)
  return df
end

function data_collector(properties::Array{Symbol}, steps_to_collect_data::Array{Int64}, model::AbstractModel, step::Integer)
  df = agents_data_complete(properties, model, step=step)
  return df
end

function data_collector(properties::Array{Symbol}, steps_to_collect_data::Array{Int64}, model::AbstractModel, step::Integer, df::DataFrame)
  d = agents_data_complete(properties, model, step=step)
  df = join(df, d, on=:id, kind=:outer)
  return df
end

"""
    combine_columns(data::DataFrame, column_names::Array{Symbol}, aggregator::Array{Function})
Combine columns of the data that contain the same type of info from different steps of the model into one column using an aggregator, e.g. mean. You should either supply all column names that contain the same type of data, or one name (as a string) that precedes a number in different columns, e.g. "pos_"{some number}.
"""
function combine_columns!(data::DataFrame, column_names::Array{Symbol}, aggregators)
  for ag in aggregators
    d = by(data, :step, column_names => x-> (ag([getproperty(x, i) for i in column_names])))
    colname = Symbol(string(column_names[1])[1:end-1] * string(ag))
    data[colname] = d[names(d)[end]]
  end
  return data
end

function combine_columns!(data::DataFrame, column_base_name::String, aggregators)
  column_names = vcat([column_base_name], [column_base_name*string(i) for i in 1:size(data)[2]])
  datanames = [string(i) for i in names(data)]
  final_names = Array{Symbol}(undef, 0)
  for cn in column_names
    if cn in datanames
      push!(final_names, Symbol(cn))
    end
  end
  combine_columns!(data, final_names, aggregators)
end

"""
Writes a dataframe to file
"""
function write_to_file(;df::DataFrame, filename::AbstractString)
  CSV.write(filename, df, append=false, delim="\t", writeheader=true)
end
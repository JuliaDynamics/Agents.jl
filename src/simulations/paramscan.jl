export paramscan

"""
    paramscan(parameters, initialize; kwargs...)

Run the model with all the parameter value combinations given in `parameters`
while initializing the model with `initialize`.
This function uses `DrWatson`'s [`dict_list`](https://juliadynamics.github.io/DrWatson.jl/dev/run&list/#DrWatson.dict_list)
internally. This means that every entry of `parameters` that is a `Vector`,
contains many parameters and thus is scanned. All other entries of
`parameters` that are not `Vector`s are not expanded in the scan.
Keys of `parameters` should be of type `Symbol`.

`initialize` is a function that creates an ABM. It should accept keyword arguments,
of which all values in `parameters` should be a subset. This means `parameters`
can take both model and agent constructor properties.

## Keywords
The following keywords modify the `paramscan` function:

- `include_constants::Bool=false` determines whether constant parameters should be
  included in the output `DataFrame`.
- `progress::Bool = true` whether to show the progress of simulations.

The following keywords are propagated into [`run!`](@ref):
```julia
agent_step!, n, when, model_step!, step0, parallel, replicates
adata, mdata
```
"""
function paramscan(parameters::Dict{Symbol,}, initialize;
  n = 1, agent_step! = dummystep,  model_step! = dummystep,
  progress::Bool = true, include_constants::Bool = false,
  kwargs...)

  if include_constants
    changing_params = collect(keys(parameters))
  else
    changing_params = [k for (k, v) in parameters if typeof(v)<:Vector]
  end

  combs = dict_list(parameters)
  ncombs = length(combs)
  counter = 0
  d, rest = Iterators.peel(combs)
  model = initialize(; d...)
  df_agent, df_model = run!(model, agent_step!, model_step!, n; kwargs...)
  addparams!(df_agent, df_model, d, changing_params)
  for d in rest
    model = initialize(; d...)
    df_agentTemp, df_modelTemp = run!(model, agent_step!, model_step!, n; kwargs...)
    addparams!(df_agentTemp, df_modelTemp, d, changing_params)
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
  progress && println()
  return df_agent, df_model
end

"""
Adds new columns for each parameter in `changing_params`.
"""
function addparams!(df_agent::AbstractDataFrame, df_model::AbstractDataFrame, params::Dict{Symbol,}, changing_params::Vector{Symbol})
    # There is duplication here, but we cannot guarantee which parameter is unique
    # to each dataframe since `initialize` is user defined.
    nrows_agent = size(df_agent, 1)
    nrows_model = size(df_model, 1)
    for c in changing_params
        if !isempty(df_model)
            df_model[!, c] = [params[c] for i in 1:nrows_model]
        end
        if !isempty(df_agent)
            df_agent[!, c] = [params[c] for i in 1:nrows_agent]
        end
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

export paramscan

"""
    paramscan(parameters, initialize; kwargs...) → adf, mdf

Perform a parameter scan of a ABM simulation output by collecting data from all
parameter combinations into dataframes (one for agent data, one for model data).
The dataframes columns are both the collected data (as in [`run!`](@ref)) but also the
input parameter values used.

`parameters` is a dictionary with key type `Symbol` which contains various parameters that
will be scanned over (as well as other parameters that remain constant).
This function uses `DrWatson`'s [`dict_list`](https://juliadynamics.github.io/DrWatson.jl/dev/run&list/#DrWatson.dict_list)
convention. This means that every entry of `parameters` that is a `Vector`
contains many parameters and thus is scanned. All other entries of
`parameters` that are not `Vector`s are not expanded in the scan.

The second argument `initialize` is a function that creates an ABM and returns it.
It must accept keyword arguments which are the *keys* of the `parameters` dictionary.
Since the user decides how to use input arguments to make an ABM, `parameters` can be
used to affect model properties, space type and creation as well as agent properties,
see the example below.

## Keywords
The following keywords modify the `paramscan` function:

- `include_constants::Bool=false` determines whether constant parameters should be
  included in the output `DataFrame`.
- `progress::Bool = true` whether to show the progress of simulations.

All other keywords are propagated into [`run!`](@ref).
Furthermore, `agent_step!, model_step!, n` are also keywords here, that are given
to [`run!`](@ref) as arguments. Naturally,
`agent_step!, model_step!, n` and at least one of `adata, mdata` are mandatory.

## Example
A runnable example that uses `paramscan` is shown in [Schelling's segregation model](@ref).
There we define
```julia
function initialize(; numagents = 320, griddims = (20, 20), min_to_be_happy = 3)
    space = GridSpace(griddims, moore = true)
    properties = Dict(:min_to_be_happy => min_to_be_happy)
    model = ABM(SchellingAgent, space;
                properties = properties, scheduler = Schedulers.randomly)
    for n in 1:numagents
        agent = SchellingAgent(n, (1, 1), false, n < numagents / 2 ? 1 : 2)
        add_agent_single!(agent, model)
    end
    return model
end
```
and do a parameter scan by doing:
```julia
happyperc(moods) = count(moods) / length(moods)
adata = [(:mood, happyperc)]

parameters = Dict(
    :min_to_be_happy => collect(2:5), # expanded
    :numagents => [200, 300],         # expanded
    :griddims => (20, 20),            # not Vector = not expanded
)

adf, _ = paramscan(parameters, initialize; adata, agent_step!, n = 3)
```
"""
function paramscan(
        parameters::Dict, initialize;
        progress::Bool = true, include_constants::Bool = false,
        n = 1, agent_step! = dummystep,  model_step! = dummystep, kwargs...
    )

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

"Add new columns for each parameter in `changing_params`."
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

    vec(map(Iterators.product(values(iterable_dict)...)) do vals
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

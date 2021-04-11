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

- `include_constants::Bool = false`: by default, only the varying parameters (Vector in
  `parameters`) will be included in the output `DataFrame`. If `true`, constant parameters
  (non-Vector in `parameteres`) will also be included.
- `parallel::Bool = false` whether `Distributed.pmap` is invoked to run simulations
  in parallel. This must be used in conjunction with `@everywhere` (see
  [Performance Tips](@ref)).

All other keywords are propagated into [`run!`](@ref).
Furthermore, `agent_step!, model_step!, n` are also keywords here, that are given
to [`run!`](@ref) as arguments. Naturally, `agent_step!, model_step!, n` and at least one
of `adata, mdata` are mandatory.
The `adata, mdata` lists shouldn't contain the parameters that are already in
the `parameters` dictionary to avoid duplication.

## Example
A runnable example that uses `paramscan` is shown in [Schelling's segregation model](@ref).
There, we define
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
    parameters::Dict,
    initialize;
    include_constants::Bool = false,
    parallel::Bool = false,
    agent_step! = dummystep,
    model_step! = dummystep,
    n = 1,
    kwargs...,
)

    if include_constants
        output_params = collect(keys(parameters))
    else
        output_params = [k for (k, v) in parameters if typeof(v) <: Vector]
    end

    combs = dict_list(parameters)

    if parallel
        all_data = ProgressMeter.@showprogress pmap(combs) do i
            run_single(i, output_params, initialize; agent_step!, model_step!, n, kwargs...)
        end
    else
        all_data = ProgressMeter.@showprogress map(combs) do i
            run_single(i, output_params, initialize; agent_step!, model_step!, n, kwargs...)
        end
    end

    df_agent = DataFrame()
    df_model = DataFrame()
    for (df1, df2) in all_data
        append!(df_agent, df1)
        append!(df_model, df2)
    end

    return df_agent, df_model
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
    end)
end

function run_single(
    param_dict::Dict,
    output_params::Vector{Symbol},
    initialize;
    agent_step! = dummystep,
    model_step! = dummystep,
    n = 1,
    kwargs...,
)
    model = initialize(; param_dict...)
    df_agent_single, df_model_single = run!(model, agent_step!, model_step!, n; kwargs...)
    output_params_dict = filter(j -> first(j) in output_params, param_dict)
    insertcols!(df_agent_single, output_params_dict...)
    insertcols!(df_model_single, output_params_dict...)
    return (df_agent_single, df_model_single)
end

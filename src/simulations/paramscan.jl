export paramscan

"""
    paramscan(parameters::AbstractDict, initialize; kwargs...) → adf, mdf

Perform a parameter scan of an ABM simulation output by collecting data from all
parameter combinations into dataframes (one for agent data, one for model data).
The dataframes columns are both the collected data (as in [`run!`](@ref)) but also the
input parameter values used.

`parameters` is a dictionary with key type `Symbol`. Each entry of the dictionary
maps a parameter key to the parameter values that should be scanned over
(or to a single parameter value that will remain constant throughout the scans).
The approach regarding `parameters` is as follows:

- If the value of a specific key is a `Vector`, all values of the vector are expended
  as values for the parameter to scan over.
- If the value of a specific key is not a `Vector`, it is assumed that whatever this
  value is, it corresponds to a single and constant parameter value and therefore it is not
  expanded or scanned over.

This is done so that parameter values that are inherently iterable (such as a `String`)
are not wrongly expanded into their constituents. (if the value of a parameter
is itself a `Vector`, then you need to pass in a vector of vectors to scan the parameter)

The second argument `initialize` is a function that creates an ABM and returns it.
It must accept keyword arguments which are the *keys* of the `parameters` dictionary.
Since the user decides how to use input arguments to make an ABM, `parameters` can be
used to affect model properties, space type and creation as well as agent properties,
see the example below.

## Keywords
The following keywords modify the `paramscan` function:

- `include_constants::Bool = false`: by default, only the varying parameters (`Vector` values
  in `parameters`) will be included in the output `DataFrame`. If `true`, constant parameters
  (non-Vector in `parameters`) will also be included.
- `parallel::Bool = false` whether `Distributed.pmap` is invoked to run simulations
  in parallel. This must be used in conjunction with `@everywhere` (see
  [Performance Tips](@ref)).
- `showprogress::Bool = false` whether a progressbar will be displayed to indicate % runs finished.

All other keywords are propagated into [`run!`](@ref).
Furthermore, `agent_step!, model_step!, n` are also keywords here, that are given
to [`run!`](@ref) as arguments. Naturally, stepping functions and the
number of time steps (`agent_step!`, `model_step!`, and `n`) and at least one
of `adata, mdata` are mandatory.
The `adata, mdata` lists shouldn't contain the parameters that are already in
the `parameters` dictionary to avoid duplication.

## Example
A runnable example that uses `paramscan` is shown in [Schelling's segregation model](@ref).
There, we define
```julia
function initialize(; numagents = 320, griddims = (20, 20), min_to_be_happy = 3)
    space = GridSpaceSingle(griddims, periodic = false)
    properties = Dict(:min_to_be_happy => min_to_be_happy)
    model = ABM(SchellingAgent, space;
                properties = properties, scheduler = Schedulers.randomly)
    for n in 1:numagents
        add_agent_single!(SchellingAgent, model, n < numagents / 2 ? 1 : 2)
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
    parameters::AbstractDict,
    initialize;
    include_constants::Bool = false,
    parallel::Bool = false,
    agent_step! = dummystep,
    model_step! = dummystep,
    n = 1,
    showprogress::Bool = false,
    kwargs...,
)
    if agent_step! == dummystep && model_step! == dummystep
        agent_step! = agent_step_field(model)
        model_step! = model_step_field(model)
    else
        @warn "some warning"
    end
    if include_constants
        output_params = collect(keys(parameters))
    else
        output_params = [k for (k, v) in parameters if typeof(v) <: Vector]
    end

    combs = dict_list(parameters)

    progress = ProgressMeter.Progress(length(combs); enabled = showprogress)
    mapfun = parallel ? pmap : map
    all_data = ProgressMeter.progress_map(combs; mapfun, progress) do comb
        run_single(comb, output_params, initialize;
                   agent_step!, model_step!, n, kwargs...)
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

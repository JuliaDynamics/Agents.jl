export ensemblerun!
Vector_or_Tuple = Union{AbstractArray,Tuple}

"""
    ensemblerun!(models::Vector, n; kwargs...)
Perform an ensemble simulation of [`run!`](@ref) for all `model ∈ models`.
Each `model` should be a (different) instance of an [`AgentBasedModel`](@ref) but probably
initialized with a different random seed or different initial agent distribution.
All models obey the same evolution rules contained in  the model and are evolved for `n`.

Similarly to [`run!`](@ref) this function will collect data. It will furthermore
add one additional column to the dataframe called `:ensemble`, which has an integer
value counting the ensemble member. The function returns `agent_df, model_df, models`.

If you want to scan parameters and at the same time run multiple simulations at each
parameter combination, simply use `seed` as a parameter, and use that parameter to
tune the model's initial random seed and/or agent distribution.

See example usage in [Schelling's segregation model](@ref).

## Keywords
The following keywords modify the `ensemblerun!` function:
- `parallel::Bool = false` whether `Distributed.pmap` is invoked to run simulations
  in parallel. This must be used in conjunction with `@everywhere` (see
  [Performance Tips](@ref)).
- `showprogress::Bool = false` whether a progressbar will be displayed to indicate % runs finished.

All other keywords are propagated to [`run!`](@ref) as-is.
"""
function ensemblerun!(
    models::Vector_or_Tuple,
    n::Union{Function, Int};
    showprogress = false,
    parallel = false,
    kwargs...,
)
    if parallel
        return parallel_ensemble(models, n;
                                 showprogress, kwargs...)
    else
        return series_ensemble(models, n;
                               showprogress, kwargs...)
    end
end

"""
    ensemblerun!(generator, n; kwargs...)
Generate many `ABM`s and propagate them into `ensemblerun!(models, ...)` using
the provided `generator` which is a one-argument function whose input is a seed.

This method has additional keywords `ensemble = 5, seeds = rand(UInt32, ensemble)`.
"""
function ensemblerun!(
    generator;
    ensemble = 5,
    seeds = rand(UInt32, ensemble),
    kwargs...,
)
    models = [generator(seed) for seed in seeds]
    ensemblerun!(models; kwargs...)
end

function series_ensemble(models, n;
                         showprogress = false, kwargs...)

    @assert models[1] isa ABM

    nmodels = length(models)
    progress = ProgressMeter.Progress(nmodels; enabled = showprogress)

    df_agent, df_model = run!(models[1], n; kwargs...)

    ProgressMeter.next!(progress)

    add_ensemble_index!(df_agent, 1)
    add_ensemble_index!(df_model, 1)

    ProgressMeter.progress_map(2:nmodels; progress) do midx

        df_agentTemp, df_modelTemp =
            run!(models[midx], n; kwargs...)

        add_ensemble_index!(df_agentTemp, midx)
        add_ensemble_index!(df_modelTemp, midx)

        append!(df_agent, df_agentTemp)
        append!(df_model, df_modelTemp)
    end

    return df_agent, df_model, models
end

function parallel_ensemble(models, n;
                           showprogress = false, kwargs...)

    progress = ProgressMeter.Progress(length(models); enabled = showprogress)
    all_data = ProgressMeter.progress_pmap(models; progress) do model
        run!(model, n; kwargs...)
    end

    df_agent = DataFrame()
    df_model = DataFrame()

    for (m, d) in enumerate(all_data)
        add_ensemble_index!(d[1], m)
        add_ensemble_index!(d[2], m)
        append!(df_agent, d[1])
        append!(df_model, d[2])
    end

    return df_agent, df_model, models
end

function add_ensemble_index!(df, m)
    df[!, :ensemble] = fill(m, size(df, 1))
end

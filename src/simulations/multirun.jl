export ensemblerun!
Vector_or_Tuple = Union{AbstractArray, Tuple}

"""
    ensemblerun!(models::Vector, agent_step!, model_step!, n; kwargs...)
Perform an ensemble simulation of [`run!`](@ref) for all `model ∈ models`.
Each `model` should be a (different) instance of an [`AgentBasedModel`](@ref) but probably
initialized with a different random seed or different initial agent distribution.
All models obey the same rules `agent_step!, model_step!` and are evolved for `n`.

Similarly to [`run!`](@ref) this function will collect data. It will furthermore
add one additional column to the dataframe called `:ensemble`, which has an integer
value counting the ensemble member. The function returns `agent_df, model_df, models`.

The keyword `parallel=true` will run the simulations in parallel using Julia's
`Distributed.pmap` (you need to have loaded `Agents` with `@everywhere`, see
docs online).

All other keywords are propagated to [`run!`](@ref) as-is.
"""
function ensemblerun!(
        models::Vector_or_Tuple, agent_step!, model_step!, n;
        parallel = false, kwargs...
    )
    if parallel
        return parallel_ensemble(models, agent_step!, model_step!, n; kwargs...)
    else
        return series_ensemble(models, agent_step!, model_step!, n; kwargs...)
    end
end

"""
    ensemblerun!(generator, agent_step!, model_step!, n; kwargs...)
Generate many `ABM`s and propagate them into `ensemblerun!(models, ...)` using the
the provided `generator` which is a one-argument function whose input is a seed.

This method has the keywords `ensemble = 5, seeds = abs.(rand(Int, ensemble))`
and the only thing it does is:
```julia
models = [generator(seed) for seed ∈ seeds]
ensemblerun!(models, args...; kwargs...)
```
"""
function ensemblerun!(
        generator, args...;
        ensemble = 5, seeds = abs.(rand(Int, ensemble)), kwargs...
    )
    models = [generator(seed) for seed ∈ seeds]
    ensemblerun!(models, args...; kwargs...)
end

function series_ensemble(models, agent_step!, model_step!, n; kwargs...)
    @assert models[1] isa ABM
    df_agent, df_model = _run!(models[1], agent_step!, model_step!, n; kwargs...)
    replicate_col!(df_agent, 1)
    replicate_col!(df_model, 1)

    for m in 2:length(models)
        df_agentTemp, df_modelTemp = _run!(models[m], agent_step!, model_step!, n; kwargs...)
        replicate_col!(df_agentTemp, m)
        replicate_col!(df_modelTemp, m)
        append!(df_agent, df_agentTemp)
        append!(df_model, df_modelTemp)
    end
    return df_agent, df_model, models
end

function parallel_ensemble(models::ABM, agent_step!, model_step!, n; kwargs...)
    all_data = pmap(
        j -> _run!(models[j], agent_step!, model_step!, n; kwargs...), 1:length(models)
    )

    df_agent = DataFrame()
    df_model = DataFrame()
    for (m, d) in enumerate(all_data)
        replicate_col!(d[1], m)
        replicate_col!(d[2], m)
        append!(df_agent, d[1])
        append!(df_model, d[2])
    end

    return df_agent, df_model, models
end

function replicate_col!(df, m)
    df[!, :ensemble] = fill(m, 1:size(df, 1))
end

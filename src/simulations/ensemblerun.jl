export ensemblerun!
Vector_or_Tuple = Union{AbstractArray,Tuple}

"""
    ensemblerun!(models::Vector, agent_step!, model_step!, n; kwargs...)
Perform an ensemble simulation of [`run!`](@ref) for all `model ∈ models`.
Each `model` should be a (different) instance of an [`AgentBasedModel`](@ref) but probably
initialized with a different random seed or different initial agent distribution.
All models obey the same rules `agent_step!, model_step!` and are evolved for `n`.

Similarly to [`run!`](@ref) this function will collect data. It will furthermore
add one additional column to the dataframe called `:ensemble`, which has an integer
value counting the ensemble member. The function returns `agent_df, model_df, models`.

The keyword `parallel = false`, when `true`, will run the simulations in parallel using
Julia's `Distributed.pmap` (you need to have loaded `Agents` with `@everywhere`, see
docs online).

All other keywords are propagated to [`run!`](@ref) as-is.

Example usage in [Schelling's segregation model](@ref).

If you want to scan parameters and at the same time run multiple simulations at each
parameter combination, simply use `seed` as a parameter, and use that parameter to
tune the model's initial random seed and agent distribution.
"""
function ensemblerun!(
    models::Vector_or_Tuple,
    agent_step!,
    model_step!,
    n;
    parallel = false,
    kwargs...,
)
    if parallel
        return parallel_ensemble(models, agent_step!, model_step!, n; kwargs...)
    else
        return series_ensemble(models, agent_step!, model_step!, n; kwargs...)
    end
end

"""
    ensemblerun!(generator, agent_step!, model_step!, n; kwargs...)
Generate many `ABM`s and propagate them into `ensemblerun!(models, ...)` using
the provided `generator` which is a one-argument function whose input is a seed.

This method has additional keywords `ensemble = 5, seeds = rand(UInt32, ensemble)`.
"""
function ensemblerun!(
    generator,
    args...;
    ensemble = 5,
    seeds = rand(UInt32, ensemble),
    kwargs...,
)
    models = [generator(seed) for seed in seeds]
    ensemblerun!(models, args...; kwargs...)
end

function series_ensemble(models, agent_step!, model_step!, n; kwargs...)
    @assert models[1] isa ABM
    df_agent, df_model = run!(models[1], agent_step!, model_step!, n; kwargs...)
    add_ensemble_index!(df_agent, 1)
    add_ensemble_index!(df_model, 1)

    for m in 2:length(models)
        df_agentTemp, df_modelTemp =
            run!(models[m], agent_step!, model_step!, n; kwargs...)
        add_ensemble_index!(df_agentTemp, m)
        add_ensemble_index!(df_modelTemp, m)
        append!(df_agent, df_agentTemp)
        append!(df_model, df_modelTemp)
    end
    return df_agent, df_model, models
end

function parallel_ensemble(models, agent_step!, model_step!, n; kwargs...)
    all_data = pmap(
        j -> run!(models[j], agent_step!, model_step!, n; kwargs...),
        1:length(models),
    )

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

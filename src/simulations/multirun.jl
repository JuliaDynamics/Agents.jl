Vector_or_Tuple = Union{AbstractArray, Tuple}

# version that takes as input generator
function multirun!(
        generator, args...;
        replicates = 5, seeds = [abs(rand(Int)) for _ in 1:replicates], kwargs...
    )
    models = [generator(seed) for seed ∈ seeds]
    multirun!(models, args...; kwargs...)
end

# version that has models already
function multirun!(
        models::Vector_or_Tuple, agent_step!, model_step!, n;
        parallel = true, kwargs...
    )
    if parallel
        return parallel_replicates(models, agent_step!, model_step!, n; kwargs...)
    else
        return series_replicates(models, agent_step!, model_step!, n; kwargs...)
    end
end

"Run replicates of the same simulation"
function series_replicates(models, agent_step!, model_step!, n, replicates; kwargs...)

    df_agent, df_model = _run!(models[1], agent_step!, model_step!, n; kwargs...)
    replicate_col!(df_agent, 1)
    replicate_col!(df_model, 1)

    for rep in 2:length(models)
        df_agentTemp, df_modelTemp = _run!(models[rep], agent_step!, model_step!, n; kwargs...)
        replicate_col!(df_agentTemp, rep)
        replicate_col!(df_modelTemp, rep)
        append!(df_agent, df_agentTemp)
        append!(df_model, df_modelTemp)
    end
    return df_agent, df_model
end

"Run replicates of the same simulation in parallel"
function parallel_replicates(model::ABM, agent_step!, model_step!, n, replicates;
    seeds = [abs(rand(Int)) for _ in 1:replicates], kwargs...)

    models = [deepcopy(model) for _ in 1:replicates-1]
    push!(models, model) # no reason to make an additional copy
    if model.rng isa MersenneTwister
        for j in 1:replicates; seed!(models[j], seeds[j]); end
    end

    all_data = pmap(
        j -> _run!(models[j], agent_step!, model_step!, n; kwargs...), 1:replicates
    )

    df_agent = DataFrame()
    df_model = DataFrame()
    for (rep, d) in enumerate(all_data)
        replicate_col!(d[1], rep)
        replicate_col!(d[2], rep)
        append!(df_agent, d[1])
        append!(df_model, d[2])
    end

    return df_agent, df_model
end

function replicate_col!(df, rep)
    df[!, :replicate] = [rep for i in 1:size(df, 1)]
end

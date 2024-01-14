
# v6 deprecations

# From before the move to an interface for ABMs and making `ABM` abstract.
AgentBasedModel(args...; kwargs...) = StandardABM(args...; kwargs...)

macro agent(new_name, base_type, super_type, extra_fields)
    # This macro was generated with the guidance of @rdeits on Discourse:
    # https://discourse.julialang.org/t/
    # metaprogramming-obtain-actual-type-from-symbol-for-field-inheritance/84912
    @warn "this version of the agent macro is deprecated. Use the new version of
         the agent macro introduced in the 6.0 release.
         The new structure is the following:

              @agent struct YourAgentType{X}(AnotherAgentType) [<: OptionalSupertype]
                  extra_property::X
                  other_extra_property_with_default::Bool = true
                  const other_extra_const_property::Int
                  # etc...
              end
          "
    # hack for backwards compatibility (PR #846)
    if base_type isa Expr
        if base_type.args[1] == :ContinuousAgent && length(base_type.args) == 2
            base_type = Expr(base_type.head, base_type.args..., :Float64)
        end
    end
    # We start with a quote. All macros return a quote to be evaluated
    quote
        let
            # Here we collect the field names and types from the base type
            # Because the base type already exists, we escape the symbols to obtain it
            base_T = $(esc(base_type))
            base_fieldnames = fieldnames(base_T)
            base_fieldtypes = fieldtypes(base_T)
            base_fieldconsts = isconst.(base_T, base_fieldnames)
            iter_fields = zip(base_fieldnames, base_fieldtypes, base_fieldconsts)
            base_fields = [c ? Expr(:const, :($f::$T)) : (:($f::$T))
                           for (f, T, c) in iter_fields]
            # Then, we prime the additional name and fields into QuoteNodes
            # We have to do this to be able to interpolate them into an inner quote.
            name = $(QuoteNode(new_name))
            additional_fields = $(QuoteNode(extra_fields.args))
            # here, we mutate any const fields defined by the consts variable in the macro
            additional_fields = filter(f -> typeof(f) != LineNumberNode, additional_fields)
            args_names = map(f -> f isa Expr ? f.args[1] : f, additional_fields)
            index_consts = findfirst(f -> f == :constants, args_names)
            if index_consts != nothing
                consts_args = eval(splice!(additional_fields, index_consts))
                for arg in consts_args
                    i = findfirst(a -> a == arg, args_names)
                    additional_fields[i] = Expr(:const, additional_fields[i])
                end
            end
            # Now we start an inner quote. This is because our macro needs to call `eval`
            # However, this should never happen inside the main body of a macro
            # There are several reasons for that, see the cited discussion at the top
            expr = quote
                # Also notice that we quote supertype and interpolate it twice
                @kwdef mutable struct $name <: $$(QuoteNode(super_type))
                    $(base_fields...)
                    $(additional_fields...)
                end
            end
            # @show expr # uncomment this to see that the final expression looks as desired
            # It is important to evaluate the macro in the module that it was called at
            Core.eval($(__module__), expr)
        end
        # allow attaching docstrings to the new struct, issue #715
        Core.@__doc__($(esc(Docs.namify(new_name))))
        nothing
    end
end

macro agent(new_name, base_type, extra_fields)
    # Here we nest one macro call into another because there is no way to provide
    # defaults for macro arguments. We proceed to call the actual macro with the default
    # `super_type = AbstractAgent`. This requires us to disable 'macro hygiene', see here
    # for a brief explanation of the potential issues with this:
    # https://discourse.julialang.org/t/calling-a-macro-from-within-a-macro-revisited/19680/16?u=fbanning
    esc(quote
        Agents.@agent($new_name, $base_type, Agents.AbstractAgent, $extra_fields)
    end)
end

function add_agent_pos!(agent::AbstractAgent, model::ABM)
    @warn "`add_agent_pos(agent, model)` is deprecated in favor of `add_agent_own_pos(agent, model)`" 
    add_agent_own_pos!(agent, model)
end

function CommonSolve.step!(model::ABM, agent_step!, n::Int=1, agents_first::Bool=true; warn_deprecation = true)
    step!(model, agent_step!, dummystep, n, agents_first; warn_deprecation = warn_deprecation)
end

function CommonSolve.step!(model::ABM, agent_step!, model_step!, n = 1, agents_first=true; warn_deprecation = true)
    if warn_deprecation
        @warn "Passing agent_step! and model_step! to step! is deprecated. Use the new version
             step!(model, n = 1, agents_first = true)"
    end
    s = 0
    while until(s, n, model)
        !agents_first && model_step!(model)
        if agent_step! ≠ dummystep
            for id in schedule(model)
                agent_step!(model[id], model)
            end
        end
        agents_first && model_step!(model)
        s += 1
    end
end

run!(model::ABM, agent_step!, n::Int = 1; warn_deprecation = true, kwargs...) =
    run!(model::ABM, agent_step!, dummystep, n; warn_deprecation = warn_deprecation, kwargs...)

function run!(model, agent_step!, model_step!, n;
        when = true,
        when_model = when,
        mdata = nothing,
        adata = nothing,
        obtainer = identity,
        agents_first = true,
        showprogress = false,
        warn_deprecation = true
    )
    if warn_deprecation
        @warn "Passing agent_step! and model_step! to run! is deprecated.
          These functions should be already contained inside the model instance."
    end
    df_agent = init_agent_dataframe(model, adata)
    df_model = init_model_dataframe(model, mdata)
    if n isa Integer
        if when == true
            for c in eachcol(df_agent)
                sizehint!(c, n)
            end
        end
        if when_model == true
            for c in eachcol(df_model)
                sizehint!(c, n)
            end
        end
    end

    s = 0
    p = if typeof(n) <: Int
        ProgressMeter.Progress(n; enabled=showprogress, desc="run! progress: ")
    else
        ProgressMeter.ProgressUnknown(desc="run! steps done: ", enabled=showprogress)
    end
    while until(s, n, model)
        if should_we_collect(s, model, when)
            collect_agent_data!(df_agent, model, adata, s; obtainer)
        end
        if should_we_collect(s, model, when_model)
            collect_model_data!(df_model, model, mdata, s; obtainer)
        end
        step!(model, agent_step!, model_step!, 1, agents_first; warn_deprecation = false)
        s += 1
        ProgressMeter.next!(p)
    end
    if should_we_collect(s, model, when)
        collect_agent_data!(df_agent, model, adata, s; obtainer)
    end
    if should_we_collect(s, model, when_model)
        collect_model_data!(df_model, model, mdata, s; obtainer)
    end
    ProgressMeter.finish!(p)
    return df_agent, df_model
end

offline_run!(model::ABM, agent_step!, n::Int = 1; warn_deprecation = true, kwargs...) =
    offline_run!(model::ABM, agent_step!, dummystep, n; warn_deprecation = warn_deprecation, kwargs...)

function offline_run!(model, agent_step!, model_step!, n;
        when = true,
        when_model = when,
        mdata = nothing,
        adata = nothing,
        obtainer = identity,
        agents_first = true,
        showprogress = false,
        backend::Symbol = :csv,
        adata_filename = "adata.$backend",
        mdata_filename = "mdata.$backend",
        writing_interval = 1,
        warn_deprecation = true
    )
    if warn_deprecation
        @warn "Passing agent_step! and model_step! to offline_run! is deprecated.
          These functions should be already contained inside the model instance."
    end
    df_agent = init_agent_dataframe(model, adata)
    df_model = init_model_dataframe(model, mdata)
    if n isa Integer
        if when == true
            for c in eachcol(df_agent)
                sizehint!(c, n)
            end
        end
        if when_model == true
            for c in eachcol(df_model)
                sizehint!(c, n)
            end
        end
    end

    writer = get_writer(backend)
    run_and_write!(model, agent_step!, model_step!, df_agent, df_model, n;
        when, when_model,
        mdata, adata,
        obtainer, agents_first,
        showprogress,
        writer, adata_filename, mdata_filename, writing_interval
    )
end

function run_and_write!(model, agent_step!, model_step!, df_agent, df_model, n;
    when, when_model,
    mdata, adata,
    obtainer, agents_first,
    showprogress,
    writer, adata_filename, mdata_filename, writing_interval
)
    s = 0
    p = if typeof(n) <: Int
        ProgressMeter.Progress(n; enabled=showprogress, desc="run! progress: ")
    else
        ProgressMeter.ProgressUnknown(desc="run! steps done: ", enabled=showprogress)
    end

    agent_count_collections = 0
    model_count_collections = 0
    while until(s, n, model)
        if should_we_collect(s, model, when)
            collect_agent_data!(df_agent, model, adata, s; obtainer)
            agent_count_collections += 1
            if agent_count_collections % writing_interval == 0
                writer(adata_filename, df_agent, isfile(adata_filename))
                empty!(df_agent)
            end
        end
        if should_we_collect(s, model, when_model)
            collect_model_data!(df_model, model, mdata, s; obtainer)
            model_count_collections += 1
            if model_count_collections % writing_interval == 0
                writer(mdata_filename, df_model, isfile(mdata_filename))
                empty!(df_model)
            end
        end
        step!(model, agent_step!, model_step!, 1, agents_first; warn_deprecation = false)
        s += 1
        ProgressMeter.next!(p)
    end

    if should_we_collect(s, model, when)
        collect_agent_data!(df_agent, model, adata, s; obtainer)
        agent_count_collections += 1
    end
    if should_we_collect(s, model, when_model)
        collect_model_data!(df_model, model, mdata, s; obtainer)
        model_count_collections += 1
    end
    # catch collected data that was not yet written to disk
    if !isempty(df_agent)
        writer(adata_filename, df_agent, isfile(adata_filename))
        empty!(df_agent)
    end
    if !isempty(df_model)
        writer(mdata_filename, df_model, isfile(mdata_filename))
        empty!(df_model)
    end

    ProgressMeter.finish!(p)
    return nothing
end

function ensemblerun!(
    models::Vector_or_Tuple,
    agent_step!,
    model_step!,
    n;
    showprogress = false,
    parallel = false,
    warn_deprecation = true,
    kwargs...,
)
    if warn_deprecation
        @warn "Passing agent_step! and model_step! to ensemblerun! is deprecated.
      These functions should be already contained inside the model instance."
    end
    if parallel
        return parallel_ensemble(models, agent_step!, model_step!, n;
                                 showprogress, kwargs...)
    else
        return series_ensemble(models, agent_step!, model_step!, n;
                               showprogress, kwargs...)
    end
end

function series_ensemble(models, agent_step!, model_step!, n;
                         showprogress = false, kwargs...)

    @assert models[1] isa ABM

    nmodels = length(models)
    progress = ProgressMeter.Progress(nmodels; enabled = showprogress)

    df_agent, df_model = run!(models[1], agent_step!, model_step!, n; kwargs...)

    ProgressMeter.next!(progress)

    add_ensemble_index!(df_agent, 1)
    add_ensemble_index!(df_model, 1)

    ProgressMeter.progress_map(2:nmodels; progress) do midx

        df_agentTemp, df_modelTemp =
            run!(models[midx], agent_step!, model_step!, n; warn_deprecation = false, kwargs...)

        add_ensemble_index!(df_agentTemp, midx)
        add_ensemble_index!(df_modelTemp, midx)

        append!(df_agent, df_agentTemp)
        append!(df_model, df_modelTemp)
    end

    return df_agent, df_model, models
end

function parallel_ensemble(models, agent_step!, model_step!, n;
                           showprogress = false, kwargs...)

    progress = ProgressMeter.Progress(length(models); enabled = showprogress)
    all_data = ProgressMeter.progress_pmap(models; progress) do model
        run!(model, agent_step!, model_step!, n; warn_deprecation = false, kwargs...)
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

function ensemblerun!(
    generator,
    args::Vararg{Any, N};
    ensemble = 5,
    seeds = rand(UInt32, ensemble),
    warn_deprecation = true,
    kwargs...,
) where {N}
    models = [generator(seed) for seed in seeds]
    ensemblerun!(models, args...; kwargs...)
end

# We use these two functions in deprecation warnings.
# In version 6.2 they have no reason to exist (when we remove deprecations)
agent_step_field(model::ABM) = getfield(model, :agent_step)
model_step_field(model::ABM) = getfield(model, :model_step)

function UnremovableABM(args::Vararg{Any, N}; kwargs...) where {N} 
    @warn "UnremovableABM is deprecated. Use StandardABM(...; container = Vector, ...) instead."
    StandardABM(args...; kwargs..., container=Vector)
end



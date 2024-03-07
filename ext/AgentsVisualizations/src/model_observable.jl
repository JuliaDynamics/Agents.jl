function Agents.ABMObservable(model::AgentBasedModel;
        agent_step! = Agents.dummystep,
        model_step! = Agents.dummystep,
        adata = nothing,
        mdata = nothing,
        when = true,
    )
    if agent_step! == Agents.dummystep && model_step! == Agents.dummystep
        agent_step! = Agents.agent_step_field(model)
        model_step! = Agents.model_step_field(model)
    end
    adf = mdf = nothing
    if !isnothing(adata)
        adf = Observable(Agents.init_agent_dataframe(model, adata))
    end
    if !isnothing(mdata)
        mdf = Observable(Agents.init_model_dataframe(model, mdata))
    end
    return ABMObservable(
        Observable(model), agent_step!, model_step!, adata, mdata, adf, mdf, Observable(0), when)
end

function Agents.step!(abmobs::ABMObservable, n; kwargs...)
    model, adf, mdf = abmobs.model, abmobs.adf, abmobs.mdf
    abmobs._offset_time[] += n
    if Agents.agent_step_field(model[]) != Agents.dummystep || Agents.model_step_field(model[]) != Agents.dummystep
        Agents.step!(model[], n; kwargs...)
    else
        Agents.step!(model[], abmobs.agent_step!, abmobs.model_step!, n; warn_deprecation = false, kwargs...)
    end
    notify(model)
    if Agents.should_we_collect(abmtime(model[]), model[], abmobs.when)
        if !isnothing(abmobs.adata)
            Agents.collect_agent_data!(adf[], model[], abmobs.adata; _offset_time=abmobs._offset_time[])
            notify(adf)
        end
        if !isnothing(abmobs.mdata)
            Agents.collect_model_data!(mdf[], model[], abmobs.mdata; _offset_time=abmobs._offset_time[])
            notify(mdf)
        end
    end
    return nothing
end

function Base.show(io::IO, abmobs::ABMObservable)
    print(io, "ABMObservable with model:\n")
    print(io, abmobs.model[])
    print(io, "\nand with data collection:\n")
    print(io, " adata: $(abmobs.adata)\n")
    print(io, " mdata: $(abmobs.mdata)")
end

function Agents.ABMObservable(model::AgentBasedModel;
        adata = nothing, mdata = nothing, when = true,
    )
    adf = mdf = nothing
    if !isnothing(adata)
        adf = Observable(Agents.init_agent_dataframe(model, adata))
    end
    if !isnothing(mdata)
        mdf = Observable(Agents.init_model_dataframe(model, mdata))
    end
    timetype = typeof(abmtime(model))
    offset_time_adf = (Ref(zero(abmtime(model))), timetype[])
    offset_time_mdf = (Ref(zero(abmtime(model))), timetype[])
    abmobs = ABMObservable(Observable(model), adata, mdata, adf, mdf, when, 
                           Observable(abmtime(model)), Observable(offset_time_adf), 
                           Observable(offset_time_mdf))
    # always collect data at initialization irrespectively of `when`:
    collect_data!(abmobs, abmobs.model[], adata, mdata, adf, mdf)
    return abmobs
end

function collect_data!(abmobs, model, adata, mdata, adf, mdf)
    if !isnothing(adata)
        Agents.collect_agent_data!(adf[], model, adata)
        notify(adf)
    end
    if !isnothing(mdata)
        Agents.collect_model_data!(mdf[], model, mdata)
        notify(mdf)
    end
    return nothing
end

function Agents.step!(abmobs::ABMObservable, t)
    model, adf, mdf = abmobs.model, abmobs.adf, abmobs.mdf
    # step the model:
    Agents.step!(model[], t)
    notify(model)
    # collect data if time and `when` satisfy it:
    if !isnothing(abmobs.adata) || !isnothing(abmobs.mdata)
        tcurrent = abmtime(model[])
        tdiff = tcurrent - abmobs.t_last_collect[]
        if Agents.should_we_collect(abmtime(model[]), tdiff, model[], abmobs.when)
            if !isnothing(abmobs.adata)
                Agents.collect_agent_data!(adf[], model[], abmobs.adata)
                notify(adf)
            end
            if !isnothing(abmobs.mdata)
                Agents.collect_model_data!(mdf[], model[], abmobs.mdata)
                notify(mdf)
            end
            abmobs.t_last_collect[] = tcurrent
        end
    end
    return abmobs
end

function Base.show(io::IO, abmobs::ABMObservable)
    print(io, "ABMObservable with model:\n")
    print(io, abmobs.model[])
    print(io, "\nand with data collection:\n")
    print(io, " adata: $(abmobs.adata)\n")
    print(io, " mdata: $(abmobs.mdata)")
end

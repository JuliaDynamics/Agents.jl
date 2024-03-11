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
    return ABMObservable(Observable(model), adata, mdata, adf, mdf, Observable(abmtime(model)), when)
end

function Agents.step!(abmobs::ABMObservable, n)
    model, adf, mdf = abmobs.model, abmobs.adf, abmobs.mdf
    abmobs._offset_time[] += n
    Agents.step!(model[], n)
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

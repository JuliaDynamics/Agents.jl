export ABMObservable

"""
    ABMObservable(model; agent_step!, model_step!, adata, mdata, when) → abmobs
`abmobs` contains all information necessary to step an agent based model interactively.
It is also returned by [`abmplot`](@ref).

Calling `Agents.step!(abmobs, n)` will step the model for `n` using the provided
`agent_step!, model_step!, n` as in [`Agents.step!`](@ref).

The fields `abmobs.model, abmobs.adf, abmobs.mdf` are _observables_ that contain
the [`AgentBasedModel`](@ref), and the agent and model dataframes with collected data.
Data are collected as described in [`Agents.run!`](@ref) using the `adata, mdata, when`
keywords. All three observables are updated on stepping (when it makes sense).
The field `abmobs.s` is also an observable containing the current step number.

All plotting and interactivity should be defined by `lift`ing these observables.
"""
struct ABMObservable{M, AS, MS, AD, MD, ADF, MDF, W}
    model::Observable{M}
    agent_step!::AS
    model_step!::MS
    adata::AD
    mdata::MD
    adf::ADF # this is `nothing` or `Observable`
    mdf::MDF # this is `nothing` or `Observable`
    s::Observable{Int}
    when::W
end

function ABMObservable(model;
        agent_step! = Agents.dummystep,
        model_step! = Agents.dummystep,
        adata = nothing,
        mdata = nothing,
        when = true,
    )
    adf = mdf = nothing
    if !isnothing(adata)
        adf = Observable(Agents.init_agent_dataframe(model, adata))
    end
    if !isnothing(mdata)
        mdf = Observable(Agents.init_model_dataframe(model, mdata))
    end
    return ABMObservable(
        Observable(model), agent_step!, model_step!, adata, mdata, adf, mdf, Observable(0), when
    )
end

function Agents.step!(abmobs::ABMObservable, n; kwargs...)
    model, adf, mdf = abmobs.model, abmobs.adf, abmobs.mdf
    Agents.step!(model[], abmobs.agent_step!, abmobs.model_step!, n; kwargs...)
    notify(model)
    abmobs.s[] = abmobs.s[] + n # increment step counter
    if Agents.should_we_collect(abmobs.s, model[], abmobs.when)
        if !isnothing(abmobs.adata)
            Agents.collect_agent_data!(adf[], model[], abmobs.adata, abmobs.s[])
            notify(adf)
        end
        if !isnothing(abmobs.mdata)
            Agents.collect_model_data!(mdf[], model[], abmobs.mdata, abmobs.s[])
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
function Agents.add_interaction!(ax, p)
    if p.add_controls[]
        @assert !isnothing(ax) "Need `ax` to add model controls."
        stepclick, resetclick = add_controls!(ax.parent, p.abmobs[], p.dt[])
        if !isempty(p.params[])
            @assert !isnothing(ax) "Need `ax` to add plots and parameter sliders."
            add_param_sliders!(ax.parent, p.abmobs[].model, p.params[], resetclick)
        end
    else
        stepclick = resetclick = nothing
    end

    return stepclick, resetclick
end

Agents.add_interaction!(ax) = add_interaction!(ax, first_abmplot_in(ax))

"Initialize standard model control buttons."
function add_controls!(fig, abmobs, dt)

    model, adata, mdata, adf, mdf, when =
    getfield.(Ref(abmobs), (:model, :adata, :mdata, :adf, :mdf, :when))

    # Create new layout for control buttons
    controllayout = fig[end+1,:][1,1] = GridLayout(tellheight = true)

    # Sliders
    if abmspace(model[]) isa Agents.ContinuousSpace
        _sleepr, _sleep0 = 0:0.01:1, 0
    else
        _sleepr, _sleep0 = 0:0.01:2, 1
    end

    dtrange = isnothing(dt) ? _default_dts_from_model(abmobs.model[]) : dt
    sg = SliderGrid(controllayout[1,1],
        (label = "dt", range = dtrange, startvalue = 1),
        (label = "sleep", range = _sleepr, startvalue = _sleep0),
    )
    dtslider, slep = [s.value for s in sg.sliders]

    # Step button
    # We need an additional observable that keep track of the last time data
    # was collected. Here collection is the same for agent of models so we need 1 variable.
    step = Button(fig, label = "step\nmodel")
    on(step.clicks) do c
        # notice that stepping the abmobs both steps the model and collects data!!!
        Agents.step!(abmobs, dtslider[])
    end
    # Run button
    run = Button(fig, label = "run\nmodel")
    isrunning = Observable(false)
    on(run.clicks) do c; isrunning[] = !isrunning[]; end
    on(run.clicks) do c
        @async while isrunning[]
            step.clicks[] = step.clicks[] + 1
            slep[] == 0 ? yield() : sleep(slep[])
            isopen(fig.scene) || break # crucial, ensures computations stop if closed window.
        end
    end
    # Reset button
    reset = Button(fig, label = "reset\nmodel")
    model0 = deepcopy(model[]) # backup initial model state
    on(reset.clicks) do c
        abmobs._offset_time[] += abmtime(model[])
        model[] = deepcopy(model0)
    end
    # Clear button
    clear = Button(fig, label = "clear\ndata")
    on(clear.clicks) do c
        reinit_dataframes!(model[], adata, mdata, adf, mdf)
        # always collect data after clear, as the dataframes have been emptied
        collect_data!(abmobs, model[], adata, mdata, adf, mdf)
        abmobs.t_last_collect[] = abmtime(model[])
    end
    # Layout buttons
    controllayout[2, :] = Makie.hbox!(step, run, reset, clear; tellwidth = false)
    return step.clicks, reset.clicks
end

_default_dts_from_model(::StandardABM) = 1:50
_default_dts_from_model(::EventQueueABM) = 0.1:0.1:10.0

"reinitialize agent and model dataframes."
function reinit_dataframes!(model, adata, mdata, adf, mdf)
    if !isnothing(adata)
        adf.val = Agents.init_agent_dataframe(model, adata)
    end
    if !isnothing(mdata)
        mdf.val = Agents.init_model_dataframe(model, mdata)
    end
    return nothing
end

"Initialize parameter control sliders."
function add_param_sliders!(fig, model, params, resetclick)
    datalayout = fig[end,:][1,2] = GridLayout(tellheight = true)

    slidervals = Dict{Symbol, Observable}()
    tuples_for_slidergrid = []
    for (i, (k, vals)) in enumerate(params)
        startvalue = has_key(abmproperties(model[]), k) ?
            get_value(abmproperties(model[]), k) : vals[1]
        label = string(k)
        push!(tuples_for_slidergrid, (;label, range = vals, startvalue))
    end
    sg = SliderGrid(datalayout[1,1], tuples_for_slidergrid...; tellheight = true)
    for (i, (l, vals)) in enumerate(params)
        slidervals[l] = sg.sliders[i].value
    end

    # Update button
    update = Button(datalayout[end+1, :], label = "update", tellwidth = false)
    on(update.clicks) do c
        for (k, v) in pairs(slidervals)
            if has_key(abmproperties(model[]), k)
                set_value!(abmproperties(model[]), k, v[])
            else
                throw(KeyError("$k"))
            end
        end
    end
    # Ensure resetted model has new parameters
    on(resetclick) do c
        update.clicks[] = update.clicks[] + 1
    end
    return nothing
end

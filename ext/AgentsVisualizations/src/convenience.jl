export abmexploration, abmvideo

function Agents.abmexploration(model;
        figure = (size = (1200, 800),),
        axis = NamedTuple(),
        alabels = nothing,
        mlabels = nothing,
        plotkwargs = NamedTuple(),
        kwargs...
    )
    fig, ax, abmobs = abmplot(model; figure, axis, warn_deprecation = false, kwargs...)
    p = first_abmplot_in(ax)

    adata, mdata = abmobs.adata, abmobs.mdata
    !isnothing(adata) && @assert eltype(adata)<:Tuple "Only aggregated agent data are allowed."
    !isnothing(alabels) && @assert length(alabels) == length(adata)
    !isnothing(mlabels) && @assert length(mlabels) == length(mdata)
    init_abm_data_plots!(fig, abmobs, adata, mdata, alabels, mlabels, plotkwargs, p.stepclick, p.resetclick)
    return fig, abmobs
end

function init_abm_data_plots!(fig, abmobs, adata, mdata, alabels, mlabels, plotkwargs, stepclick, resetclick)
    La = isnothing(adata) ? 0 : size(abmobs.adf[])[2]-1
    Lm = isnothing(mdata) ? 0 : size(abmobs.mdf[])[2]-1
    La + Lm == 0 && return nothing # failsafe; don't add plots if dataframes are empty

    plotlayout = fig[:, end+1] = GridLayout(tellheight = false)
    axs = []

    for i in 1:La # add adata plots
        y_label = string(adata[i][2]) * "_" * string(adata[i][1])
        points = @lift(Point2f.($(abmobs.adf).time, $(abmobs.adf)[:,y_label]))
        ax = plotlayout[i, :] = Axis(fig)
        push!(axs, ax)
        ax.ylabel = isnothing(alabels) ? y_label : alabels[i]
        c = JULIADYNAMICS_COLORS[mod1(i, 3)]
        scatterlines!(ax, points;
            color = c, strokecolor = c, strokewidth = 0.5,
            label = ax.ylabel, plotkwargs...
        )
    end

    for i in 1:Lm # add mdata plots
        y_label = string(mdata[i])
        points = @lift(Point2f.($(abmobs.mdf).time, $(abmobs.mdf)[:,y_label]))
        ax = plotlayout[i+La, :] = Axis(fig)
        push!(axs, ax)
        ax.ylabel = isnothing(mlabels) ? y_label : mlabels[i]
        c = JULIADYNAMICS_COLORS[mod1(i+La, 3)]
        scatterlines!(ax, points;
            color = c, strokecolor = c, strokewidth = 0.5,
            label = ax.ylabel, plotkwargs...
        )
    end

    if La+Lm > 1
        for ax in @view(axs[1:end-1]); hidexdecorations!(ax, grid = false); end
    end
    axs[end].xlabel = "time"

    # Trigger correct, and efficient, linking of x-axis
    linkxaxes!(axs[end], axs[1:end-1]...)
    on(stepclick) do clicks
        xlims!(axs[1], Makie.xautolimits(axs[1]))
        for ax in axs
            ylims!(ax, Makie.yautolimits(ax))
        end
    end
    on(resetclick) do clicks

        for ax in axs
            vlines!(ax, [abmobs._offset_time[]], color = "#c41818")
        end
    end
    return nothing
end


##########################################################################################

function Agents.abmvideo(file, model;
        spf = 1, framerate = 30, frames = 300,  title = "", showstep = true,
        figure = (size = (600, 600),), axis = NamedTuple(),
        recordkwargs = (compression = 20,), kwargs...
    )
    # add some title stuff
    abmtime_obs = Observable(abmtime(model))
    if title ≠ "" && showstep
        t = lift(x -> title*", time = "*string(x), abmtime_obs)
    elseif showstep
        t = lift(x -> "time = "*string(x), abmtime_obs)
    else
        t = title
    end
    axis = (title = t, titlealign = :left, axis...)

    agent_step! = Agents.agent_step_field(model)
    model_step! = Agents.model_step_field(model)
    fig, ax, abmobs = abmplot(model;
    add_controls = false, warn_deprecation = false, agent_step!, model_step!, figure, axis, kwargs...)

    resize_to_layout!(fig)

    record(fig, file; framerate, recordkwargs...) do io
        for j in 1:frames-1
            recordframe!(io)
            Agents.step!(abmobs, spf)
            abmtime_obs[] = abmtime(model)
        end
        recordframe!(io)
    end
    return nothing
end

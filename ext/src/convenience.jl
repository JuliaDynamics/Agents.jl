export abmexploration, abmvideo
@deprecate abm_data_exploration abmexploration
@deprecate abm_video abmvideo

"""
    abmexploration(model::ABM; alabels, mlabels, kwargs...)

Open an interactive application for exploring an agent based model and
the impact of changing parameters on the time evolution. Requires `Agents`.

The application evolves an ABM interactively and plots its evolution, while allowing
changing any of the model parameters interactively and also showing the evolution of
collected data over time (if any are asked for, see below).
The agent based model is plotted and animated exactly as in [`abmplot`](@ref),
and the `model` argument as well as splatted `kwargs` are propagated there as-is.
This convencience function *only works for aggregated agent data*.

Calling `abmexploration` returns: `fig::Figure, abmobs::ABMObservable`. So you can save 
and/or further modify the figure and it is also possible to access the collected data 
(if any) via the `ABMObservable`.

Clicking the "reset" button will add a red vertical line to the data plots for visual
guidance.

## Keywords arguments (in addition to those in `abmplot`)
* `alabels, mlabels`: If data are collected from agents or the model with `adata, mdata`,
  the corresponding plots' y-labels are automatically named after the collected data.
  It is also possible to provide `alabels, mlabels` (vectors of strings with exactly same
  length as `adata, mdata`), and these labels will be used instead.
* `figure = NamedTuple()`: Keywords to customize the created Figure.
* `axis = NamedTuple()`: Keywords to customize the created Axis.
* `plotkwargs = NamedTuple()`: Keywords to customize the styling of the resulting
  [`scatterlines`](https://makie.juliaplots.org/dev/examples/plotting_functions/scatterlines/index.html) plots.
"""
function abmexploration(model;
        figure = NamedTuple(),
        axis = NamedTuple(),
        alabels = nothing,
        mlabels = nothing,
        plotkwargs = NamedTuple(),
        kwargs...
    )
    fig, ax, abmobs = abmplot(model; figure, axis, kwargs...)
    abmplot_object = ax.scene.plots[1]

    adata, mdata = abmobs.adata, abmobs.mdata
    !isnothing(adata) && @assert eltype(adata)<:Tuple "Only aggregated agent data are allowed."
    !isnothing(alabels) && @assert length(alabels) == length(adata)
    !isnothing(mlabels) && @assert length(mlabels) == length(mdata)
    init_abm_data_plots!(fig, abmobs, adata, mdata, alabels, mlabels, plotkwargs, abmplot_object.stepclick, abmplot_object.resetclick)
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
        points = @lift(Point2f.($(abmobs.adf).step, $(abmobs.adf)[:,y_label]))
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
        points = @lift(Point2f.($(abmobs.mdf).step, $(abmobs.mdf)[:,y_label]))
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
    axs[end].xlabel = "step"

    # Trigger correct, and efficient, linking of x-axis
    linkxaxes!(axs[end], axs[1:end-1]...)
    on(stepclick) do clicks
        xlims!(axs[1], Makie.MakieLayout.xautolimits(axs[1]))
        for ax in axs
            ylims!(ax, Makie.MakieLayout.yautolimits(ax))
        end
    end
    on(resetclick) do clicks
        for ax in axs
            vlines!(ax, [abmobs.s.val], color = "#c41818")
        end
    end
    return nothing
end


##########################################################################################
"""
    abmvideo(file, model, agent_step! [, model_step!]; kwargs...)
This function exports the animated time evolution of an agent based model into a video
saved at given path `file`, by recording the behavior of the interactive version of
[`abmplot`](@ref) (without sliders).
The plotting is identical as in [`abmplot`](@ref) and applicable keywords are propagated.

## Keywords
* `spf = 1`: Steps-per-frame, i.e. how many times to step the model before recording a new
  frame.
* `framerate = 30`: The frame rate of the exported video.
* `frames = 300`: How many frames to record in total, including the starting frame.
* `title = ""`: The title of the figure.
* `showstep = true`: If current step should be shown in title.
* `figure = NamedTuple()`: Figure related keywords (e.g. resolution, backgroundcolor).
* `axis = NamedTuple()`: Axis related keywords (e.g. aspect).
* `recordkwargs = NamedTuple()`: Keyword arguments given to `Makie.record`.
  You can use `(compression = 1, profile = "high")` for a higher quality output,
  and prefer the `CairoMakie` backend.
  (compression 0 results in videos that are not playable by some software)
* `kwargs...`: All other keywords are propagated to [`abmplot`](@ref).
"""
function abmvideo(file, model, agent_step!, model_step! = Agents.dummystep;
        spf = 1, framerate = 30, frames = 300,  title = "", showstep = true,
        figure = (resolution = (600, 600),), axis = NamedTuple(),
        recordkwargs = (compression = 20,), kwargs...
    )
    # add some title stuff
    s = Observable(0) # counter of current step
    if title ≠ "" && showstep
        t = lift(x -> title*", step = "*string(x), s)
    elseif showstep
        t = lift(x -> "step = "*string(x), s)
    else
        t = title
    end
    axis = (title = t, titlealign = :left, axis...)

    fig, ax, abmobs = abmplot(model;
    add_controls = false, agent_step!, model_step!, figure, axis, kwargs...)

    resize_to_layout!(fig)

    record(fig, file; framerate, recordkwargs...) do io
        for j in 1:frames-1
            recordframe!(io)
            Agents.step!(abmobs, spf)
            s[] += spf; s[] = s[]
        end
        recordframe!(io)
    end
    return nothing
end

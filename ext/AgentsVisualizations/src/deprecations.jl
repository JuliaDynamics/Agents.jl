function Agents.abmvideo(file, model, agent_step!, model_step! = Agents.dummystep;
        spf = 1, framerate = 30, frames = 300,  title = "", showstep = true,
        figure = (resolution = (600, 600),), axis = NamedTuple(),
        recordkwargs = (compression = 20,), kwargs...
    )
    @warn "Passing agent_step! and model_step! to abmvideo is deprecated.
      These functions should be already contained inside the model instance." maxlog=1
    # add some title stuff
    if title ≠ "" && showstep
        t = lift(x -> title*", step = "*string(x), abmtime(model))
    elseif showstep
        t = lift(x -> "step = "*string(x), abmtime(model))
    else
        t = title
    end
    axis = (title = t, titlealign = :left, axis...)

    fig, ax, abmobs = abmplot(model;
    add_controls = false, warn_deprecation = false, agent_step!, model_step!, figure, axis, kwargs...)

    resize_to_layout!(fig)

    record(fig, file; framerate, recordkwargs...) do io
        for j in 1:frames-1
            recordframe!(io)
            Agents.step!(abmobs, spf)
        end
        recordframe!(io)
    end
    return nothing
end
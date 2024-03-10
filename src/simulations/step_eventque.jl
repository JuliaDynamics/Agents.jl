
function CommonSolve.step!(model::EventQueueABM, t::Union{Real, Function})
    queue = abmqueue(model)
    model_t = getfield(model, :time)
    step_ahead!(queue, model_t, t, model)
    return model
end
function CommonSolve.step!(model::EventQueueABM)
    queue = abmqueue(model)
    model_t = getfield(model, :time)
    one_step!(queue, model_t, model)
    return model
end

function step_ahead!(queue, model_t, t::Real, model::EventQueueABM)
    t0 = model_t[]
    stop_time = t0 + t
    while until(model_t[], t0, t, model)
        one_step!(queue, model_t, stop_time, model)
    end
    return
end
function step_ahead!(queue, model_t, f::Function, model::EventQueueABM)
    t0 = model_t[]
    while until(model_t[], t0, f, model)
        one_step!(queue, model_t, model)
    end
    return
end

function one_step!(queue, model_t, stop_time, model)
    if isempty(queue)
        model_t[] = stop_time
        return
    end
    event_tuple, t_event = dequeue_pair!(queue)
    if t_event > stop_time
        model_t[] = stop_time
        enqueue!(queue, event_tuple => t_event)
    else
        model_t[] = t_event
        process_event!(event_tuple, model)
    end
    return
end
function one_step!(queue, model_t, model)
    isempty(queue) && return
    event_tuple, t_event = dequeue_pair!(queue)
    model_t[] = t_event
    process_event!(event_tuple, model)
    return
end

function process_event!(event_tuple, model)
    id, event_idx = event_tuple
    !agent_not_removed(id, model) && return
    agent = model[id]
    agentevent = abmevents(model)[event_idx]
    agentevent.action!(agent, model)
    !agent_not_removed(id, model) && return
    if getfield(model, :autogenerate_after_action)
        add_event!(agent, model)
    end
    return
end

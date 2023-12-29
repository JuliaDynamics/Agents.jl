import CommonSolve
using CommonSolve: step!
export step!, dummystep

"""
    step!(model::ABM)

Perform one simulation step for the `model`.
For continuous time models, this means to run to the model
up to the next event and perform that.

    step!(model::ABM, t::Real)

Step the model forwards for total time `t`.
For discrete time models such as [`StandardABM`](@ref),
`t` must be an integer.

    step!(model::ABM, f::Function)

Step the model forwards until `f(model, t)` returns `true`,
where `t` is the current amount of time the model has been evolved
for, starting from 0.

See also [Advanced stepping](@ref).
"""
function CommonSolve.step!(model::ABM, n::Union{Real, Function} = 1)
    agent_step! = agent_step_field(model)
    model_step! = model_step_field(model)
    t = getfield(model, :time)
    step_ahead!(model, agent_step!, model_step!, n, t)
    return model
end

function step_ahead!(model::ABM, agent_step!, model_step!, n, t)
    agents_first = getfield(model, :agents_first)
    t0 = t[]
    while until(t[], t0, n, model)
        !agents_first && model_step!(model)
        for id in schedule(model)
            agent_step!(model[id], model)
        end
        agents_first && model_step!(model)
        t[] += 1
    end
end
function step_ahead!(model::ABM, agent_step!::typeof(dummystep), model_step!, n, t)
    t0 = t[]
    while until(t[], t0, n, model)
        model_step!(model)
        t[] += 1
    end
    return model
end

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
    agent_was_removed(id, model) && return
    agent = model[id]
    agentevent = abmevents(model)[event_idx]
    agentevent.action!(agent, model)
    agent_was_removed(id, model) && return
    if getfield(model, :autogenerate_after_action)
        add_event!(agent, model)
    end
    return
end

agent_was_removed(id, model::DictABM) = !haskey(agent_container(model), id)
agent_was_removed(::Int, ::VecABM) = false

until(t1, t0, n::Real, ::ABM) = t1 < t0+n
until(t1, t0, f, model::ABM) = !f(model, t1-t0)

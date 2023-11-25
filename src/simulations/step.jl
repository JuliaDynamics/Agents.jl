import CommonSolve
using CommonSolve: step!
export step!, dummystep

"""
    step!(model::AgentBasedModel)

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
function CommonSolve.step!(model::StandardABM, n::Union{Function, Int} = 1)
    agent_step! = agent_step_field(model)
    model_step! = model_step_field(model)
    if agent_step! == dummystep
        s = 0
        while until(s, n, model)
            model_step!(model)
            s += 1
        end
    else
        agents_first = getfield(model, :agents_first)
        s = 0
        while until(s, n, model)
            !agents_first && model_step!(model)
            for id in schedule(model)
                agent_step!(model[id], model)
            end
            agents_first && model_step!(model)
            s += 1
        end
    end
end

# TODO: Unify this function with the `f::Function` step.
function CommonSolve.step!(model::EventQueueABM, t::Real)
    model_t = getfield(model, :time)
    t0 = model_t[]
    while model_t[] < t0 + t
        event_tuple, t_event = dequeue_pair!(abmqueue(model))
        model_t[] = t_event
        process_event!(event_tuple, model)
    end
end

function process_event!(event_tuple, model)
    id, event_idx = event_tuple
    # if agent has been removed by other actions, return
    !haskey(agent_container(model), id) && return
    # Else, perform event action
    agent = model[id]
    agentevent = abmevents(model)[event_idx]
    agentevent.action!(agent, model)
    # if agent got deleted after the action, return again
    !haskey(agent_container(model), id) && return
    # else, generate a new event
    generate_event_in_queue!(agent, model)
    return
end

until(s, n::Int, model) = s < n
until(s, f, model) = !f(model, s)

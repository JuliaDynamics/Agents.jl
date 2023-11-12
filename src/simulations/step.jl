import CommonSolve
using CommonSolve: step!
export step!, dummystep

"""
    step!(model::ABM [, n::Int = 1])

Evolve the model for `n` steps according to the evolution rule.

    step!(model, f::Function)

In this version, `step!` runs the model until `f(model, s)` returns `true`, where `s` is the
current amount of steps taken, starting from 0.

See also [Advanced stepping](@ref) for stepping complex models where `agent_step!` might
not be convenient.
"""
function CommonSolve.step!(model::ABM, n::Union{Function, Int} = 1)
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

"""
    step!(model::EventQueueABM, t::Real)

Evolve the model executing the scheduled events until the time 
reaches the current time + `t`.
"""
function CommonSolve.step!(model::EventQueueABM, t::Real)
    model_t = getfield(model, :time)
    t0 = model_t[]
    while model_t[] < t0 + t
        event, t_event = dequeue_pair!(abmqueue(model))
        process_event!(event, model)
        model_t[] = t_event
    end
end

function process_event!(event, model)
    id, event_idx = event.id, event.event_index
    !haskey(agent_container(model), id) && return
    agent = model[id]
    agent_type = findfirst(isequal(typeof(agent)), tuple_agenttype(model))
    event_function! = abmevents(model)[agent_type][event_idx]
    event_function!(agent, model)
    !haskey(agent_container(model), id) && return
    propensities = abmrates(agent, model) .* nagents(model)
    total_propensities = sum(propensities)
    t = abmtime(model) + randexp(abmrng(model)) * total_propensities
    new_event_idx = select_event(propensities, total_propensities, model)
    enqueue!(abmqueue(model), Event(id, new_event_idx) => t)
    return
end

function select_event(propensities, total_propensities, model)
    cum_p = accumulate(+, propensities ./ total_propensities)
    p = rand(abmrng(model))
    return findfirst(c -> p <= c, cum_p)
end

"""
    dummystep(model)

Used instead of `model_step!` in [`step!`](@ref) if no function is useful to be defined.

    dummystep(agent, model)

Used instead of `agent_step!` in [`step!`](@ref) if no function is useful to be defined.
"""
dummystep(model) = nothing
dummystep(agent, model) = nothing

until(s, n::Int, model) = s < n
until(s, f, model) = !f(model, s)

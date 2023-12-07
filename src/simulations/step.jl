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
end

until(t1, t0, n::Int, model) = t1 < t0+n
until(t1, t0, f, model) = !f(model, t1-t0)

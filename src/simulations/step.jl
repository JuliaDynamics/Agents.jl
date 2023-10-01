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
    dummystep(model)

Used instead of `model_step!` in [`step!`](@ref) if no function is useful to be defined.

    dummystep(agent, model)

Used instead of `agent_step!` in [`step!`](@ref) if no function is useful to be defined.
"""
dummystep(model) = nothing
dummystep(agent, model) = nothing

until(s, n::Int, model) = s < n
until(s, f, model) = !f(model, s)

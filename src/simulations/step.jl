import CommonSolve
using CommonSolve: step!
export step!, dummystep

"""
    step!(model::ABM, n::Int = 1, agents_first::Bool = true)

Update agents `n` steps according to the stepping function `agent_step!`.
Agents will be activated as specified by the `abmscheduler(model)`.
The `model_step!` function passed to the model is triggered _after_ every 
scheduled agent has acted, unless the argument `agents_first` is `false` 
(which then first calls `model_step!` and then activates the agents).

`step!` ignores scheduled IDs that do not exist within the model, allowing
you to safely remove agents dynamically.

    step!(model, f::Function, agents_first::Bool = true)

In this version, `step!` runs the model until `f(model, s)` returns `true`, where `s` is the
current amount of steps taken, starting from 0.

See also [Advanced stepping](@ref) for stepping complex models where `agent_step!` might
not be convenient.
"""
function CommonSolve.step!(model::ABM, n::Union{Function, Int} = 1, agents_first::Bool = true)
    agent_step!, model_step! = agent_step_field(model), model_step_field(model)
    s = 0
    while until(s, n, model)
        !agents_first && model_step!(model)
        if agent_step! ≠ dummystep
            for id in schedule(model)
                agent_step!(model[id], model)
            end        
        end
        agents_first && model_step!(model)
        s += 1
    end
end

dummystep(model) = nothing
dummystep(agent, model) = nothing

until(s, n::Int, model) = s < n
until(s, f, model) = !f(model, s)

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
for, starting from the model's initial time.

See also [Advanced stepping](@ref).
"""
function CommonSolve.step!(model::AgentBasedModel, args...)
    error("`step!` not implemented yet for model of type $(typeof(model)).")
    return model
end

# Generic functions that are used in the stepping of all types of models
# this one is a type dispatch for whether the model is "unremovable" or not
agent_not_removed(id, model::DictABM) = hasid(model, id)
agent_not_removed(::Int, ::VecABM) = true
# this one just checks until when we should step in a `while` loop
until(t1, t0, n::Real, ::ABM) = t1 < t0+n
until(t1, t0, f, model::ABM) = !f(model, t1-t0)

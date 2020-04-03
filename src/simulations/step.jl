export step!, dummystep

"""
    step!(model, agent_step! [, model_step!], n::Integer = 1)

Update agents `n` steps. Agents will be updated as specified by the `model.scheduler`.
If given the optional function `model_step!`, it is triggered _after_ every scheduled
agent has acted.

    step!(model, agent_step! [, model_step!], n::Function)

`n` can be also be a function.
Then `step!` runs the model until `n(model, s)` returns `true`, where `s` is the
current amount of steps taken (starting from 0).
"""
function step! end

"""
    dummystep(model)

Ignore the model dynamics on this `step!`. Use instead of `model_step!`.
"""
dummystep(model) = nothing
"""
    dummystep(agent, model)

Ignore the agent dynamics on this `step!`. Use instead of `agent_step!`.
"""
dummystep(agent, model) = nothing

until(ss, n::Int, model) = ss < n
until(ss, n, model) = !n(model, ss)

step!(model::ABM, agent_step!, n = 1) = step!(model, agent_step!, dummystep, n)

function step!(model::ABM, agent_step!, model_step!, n)
  s = 0
  while until(s, n, model)
    activation_order = model.scheduler(model)
    for index in activation_order
      agent_step!(model.agents[index], model)
    end
    model_step!(model)
    s += 1
  end
end

function step!(model, agent_step!, model_step!, n; kwargs...)
  @warn "`step!` with keyword arguments is deprecated. Use `run!` instead."
  run!(model, agent_step!, model_step!, n; kwargs...)
end

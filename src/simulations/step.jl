export step!, dummystep

"""
    step!(model, agent_step!, n::Integer = 1)
    step!(model, agent_step!, model_step!, n::Integer = 1)

Update agents `n` steps. Agents will be updated as specified by the `model.scheduler`.
In the second version `model_step!` is triggered _after_ every scheduled agent has acted.

    step!(model, agent_step!, model_step!, n::Function)

`n` can be also be a function.
Then `step!` runs the model until `n(model, s)` returns `true`, where `s` is the
current amount of steps taken (starting from 0).
(in this case `model_step!` must be provided always)
"""
function step! end

"""
    dummystep(model)

Ignore the model dynamics. Use instead of `model_step!`.
"""
dummystep(model) = nothing
"""
    dummystep(agent, model)

Ignore the agent dynamics. Use instead of `agent_step!`.
"""
dummystep(agent, model) = nothing

until(ss, n::Int, model) = ss < n
until(ss, n, model) = !n(model, ss)

step!(model::ABM, agent_step!, n::Int=1, agents_first::Bool=true) = step!(model, agent_step!, dummystep, n)

function step!(model::ABM, agent_step!, model_step!, n = 1, agents_first=true)
  s = 0
  while until(s, n, model)
    if agents_first
      activation_order = model.scheduler(model)
      for index in activation_order
        haskey(model.agents, index) || continue
        agent_step!(model.agents[index], model)
      end
      model_step!(model)
    else
      model_step!(model)
      activation_order = model.scheduler(model)
      for index in activation_order
        haskey(model.agents, index) || continue
        agent_step!(model.agents[index], model)
      end
    end
    s += 1
  end
end

function step!(model, agent_step!, model_step!, n, agents_first; kwargs...)
  @warn "`step!` with keyword arguments is deprecated. Use `run!` instead."
  run!(model, agent_step!, model_step!, n, agents_first; kwargs...)
end

function CommonSolve.step!(model::ReinforcementLearningABM, n::Union{Real,Function}=1)
    agent_step! = agent_step_field(model)
    model_step! = model_step_field(model)
    t = getfield(model, :time)
    step_ahead_rl!(model, agent_step!, model_step!, n, t)
    return model
end

function step_ahead_rl!(model::ReinforcementLearningABM, agent_step!, model_step!, n, t)
    agents_first = getfield(model, :agents_first)
    t0 = t[]
    while until(t[], t0, n, model)
        !agents_first && model_step!(model)
        for id in schedule(model)
            # ensure we don't act on agent that doesn't exist
            agent_not_removed(id, model) || continue

            # Use RL-based stepping if in RL mode and policies are available
            agent = model[id]
            if !isnothing(model.rl_config[]) && haskey(model.trained_policies, typeof(agent))
                # Use trained policy for this agent
                rl_agent_step!(agent, model)
            else
                # Use standard agent stepping
                agent_step!(agent, model)
            end
        end
        agents_first && model_step!(model)
        t[] += 1
    end
end

function step_ahead_rl!(model::ReinforcementLearningABM, agent_step!::typeof(dummystep), model_step!, n, t)
    t0 = t[]
    while until(t[], t0, n, model)
        model_step!(model)
        t[] += 1
    end
    return model
end

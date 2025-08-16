function Agents.CommonSolve.step!(model::ReinforcementLearningABM, n::Union{Real,Function}=1)
    agent_step! = Agents.agent_step_field(model)
    model_step! = Agents.model_step_field(model)
    t = getfield(model, :time)
    Agents.step_ahead_rl!(model, agent_step!, model_step!, n, t)
    return model
end

"""
    rl_agent_step!(agent, model)

Default agent stepping function for RL agents. This will use trained policies
if available, otherwise fall back to random actions.
"""
function Agents.rl_agent_step!(agent, model)
    if model isa ReinforcementLearningABM
        agent_type = typeof(agent)

        if haskey(model.trained_policies, agent_type) && !isnothing(model.rl_config[])
            # Use trained policy
            config = model.rl_config[]
            obs = config.observation_fn(model, agent.id, get(config, :observation_radius, 2))
            obs_vec = config.observation_to_vector_fn(obs)
            action = Crux.action(model.trained_policies[agent_type], obs_vec)
            config.agent_step_fn(agent, model, action[1])
        else
            # Fall back to random behavior
            if !isnothing(model.rl_config[]) && haskey(model.rl_config[].action_spaces, agent_type)
                action_space = model.rl_config[].action_spaces[agent_type]
                action = rand(abmrng(model), action_space.vals)
                model.rl_config[].agent_step_fn(agent, model, action)
            else
                # Do nothing if no RL configuration available
                println("Warning: No trained policy or action space defined for agent type $agent_type. Skipping step.")
                return
            end
        end
    else
        error("rl_agent_step! can only be used with ReinforcementLearningABM models.")
    end
end

function Agents.step_ahead_rl!(model::ReinforcementLearningABM, agent_step!, model_step!, n, t)
    agents_first = getfield(model, :agents_first)
    t0 = t[]
    while Agents.until(t[], t0, n, model)
        !agents_first && model_step!(model)
        for id in Agents.schedule(model)
            # ensure we don't act on agent that doesn't exist
            Agents.agent_not_removed(id, model) || continue

            # Use RL-based stepping if in RL mode and policies are available
            agent = model[id]
            if !isnothing(model.rl_config[]) && haskey(model.trained_policies, typeof(agent))
                # Use trained policy for this agent
                Agents.rl_agent_step!(agent, model)
            else
                # Use standard agent stepping
                agent_step!(agent, model)
            end
        end
        agents_first && model_step!(model)
        t[] += 1
    end
end

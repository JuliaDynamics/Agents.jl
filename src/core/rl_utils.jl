using POMDPs
using Crux
using Distributions: Dirac

"""
    RLEnvironmentWrapper{M} <: POMDPs.POMDP{Vector{Float32}, Int, Vector{Float32}}

A wrapper around `ReinforcementLearningABM` that implements the POMDPs.POMDP interface
to enable training with RL algorithms that require POMDPs compatibility.

This wrapper delegates all POMDPs interface calls to the underlying 
`ReinforcementLearningABM` while presenting it as a proper POMDPs.POMDP.

# Fields
- `model::M`: The wrapped ReinforcementLearningABM instance
"""
struct RLEnvironmentWrapper{M<:ReinforcementLearningABM} <: POMDPs.POMDP{Vector{Float32},Int,Vector{Float32}}
    model::M
end

export RLEnvironmentWrapper, wrap_for_rl_training

"""
    wrap_for_rl_training(model::ReinforcementLearningABM) → RLEnvironmentWrapper

Wrap a ReinforcementLearningABM in an RLEnvironmentWrapper to make it compatible
with POMDPs-based RL training algorithms.

# Arguments
- `model`: The ReinforcementLearningABM to wrap

# Returns
- An RLEnvironmentWrapper that can be used with Crux.solve and other POMDPs functions

# Example
```julia
model = ReinforcementLearningABM(TestAgent, GridSpace((5, 5)), config)
env = wrap_for_rl_training(model)
solver = PPO(π=policy, S=observations(env), N=1000)
solve(solver, env)
```
"""
function wrap_for_rl_training(model::ReinforcementLearningABM)
    return RLEnvironmentWrapper(model)
end

"""
    POMDPs.actions(wrapper::RLEnvironmentWrapper)

Get the action space for the currently training agent type.
"""
function POMDPs.actions(wrapper::RLEnvironmentWrapper)
    model = wrapper.model
    if isnothing(model.rl_config[])
        error("RL configuration not set. Use set_rl_config! first.")
    end

    current_agent_type = get_current_training_agent_type(model)
    config = model.rl_config[]

    if haskey(config.action_spaces, current_agent_type)
        return config.action_spaces[current_agent_type]
    else
        error("No action space defined for agent type $current_agent_type")
    end
end

"""
    POMDPs.observations(wrapper::RLEnvironmentWrapper)

Get the observation space for the currently training agent type.
"""
function POMDPs.observations(wrapper::RLEnvironmentWrapper)
    model = wrapper.model
    if isnothing(model.rl_config[])
        error("RL configuration not set. Use set_rl_config! first.")
    end

    current_agent_type = get_current_training_agent_type(model)
    config = model.rl_config[]

    if haskey(config.observation_spaces, current_agent_type)
        return config.observation_spaces[current_agent_type]
    else
        # Return default observation space with smaller dimensions
        println("WARNING: No observation space found for agent type $current_agent_type, using default")
        return Crux.ContinuousSpace((10,), Float32)
    end
end

"""
    POMDPs.observation(wrapper::RLEnvironmentWrapper, s::Vector{Float32})

Get the observation for the current training agent.
"""
function POMDPs.observation(wrapper::RLEnvironmentWrapper, s::Vector{Float32})
    model = wrapper.model
    if isnothing(model.rl_config[])
        error("RL configuration not set. Use set_rl_config! first.")
    end

    current_agent = get_current_training_agent(model)
    if isnothing(current_agent)
        # Return zero observation with correct dimensions
        obs_space = POMDPs.observations(wrapper)
        obs_dims = Crux.dim(obs_space)
        return zeros(Float32, obs_dims...)
    end

    config = model.rl_config[]
    obs_radius = get(config, :observation_radius, 2)

    # Get observation using the configured function
    obs = config.observation_fn(model, current_agent.id, obs_radius)
    return config.observation_to_vector_fn(obs)
end

"""
    POMDPs.initialstate(wrapper::RLEnvironmentWrapper)

Initialize the state for a new episode.
"""
function POMDPs.initialstate(wrapper::RLEnvironmentWrapper)
    model = wrapper.model
    if isnothing(model.rl_config[])
        error("RL configuration not set. Use set_rl_config! first.")
    end

    #println("DEBUG RESET: Resetting model for new episode")

    # Reset the model to initial state
    reset_model_for_episode!(model)

    #println("DEBUG RESET: Model reset complete, time: $(abmtime(model)), training agent ID: $(model.current_training_agent_id[])")

    # Return initial state
    current_agent_type = get_current_training_agent_type(model)
    config = model.rl_config[]

    if haskey(config, :state_spaces) && haskey(config.state_spaces, current_agent_type)
        state_dims = Crux.dim(config.state_spaces[current_agent_type])
    else
        state_dims = (10,)  # Default state dimensions
    end

    return Dirac(zeros(Float32, state_dims...))
end

"""
    POMDPs.initialobs(wrapper::RLEnvironmentWrapper, initial_state::Vector{Float32})

Get the initial observation for a new episode.
"""
function POMDPs.initialobs(wrapper::RLEnvironmentWrapper, initial_state::Vector{Float32})
    obs = POMDPs.observation(wrapper, initial_state)
    return Dirac(obs)
end

"""
    POMDPs.gen(wrapper::RLEnvironmentWrapper, s, action::Int, rng::AbstractRNG)

Generate the next state, observation, and reward after taking an action.
"""
function POMDPs.gen(wrapper::RLEnvironmentWrapper, s, action::Int, rng::AbstractRNG)
    model = wrapper.model
    if isnothing(model.rl_config[])
        error("RL configuration not set. Use set_rl_config! first.")
    end

    current_agent = get_current_training_agent(model)

    if isnothing(current_agent)
        # Episode terminated
        obs_space = POMDPs.observations(wrapper)
        obs_dims = Crux.dim(obs_space)
        return (sp=s, o=zeros(Float32, obs_dims...), r=-10.0)
    end

    config = model.rl_config[]

    # Record initial state for reward calculation
    initial_state = deepcopy(model)

    # Execute the action using the configured stepping function
    config.agent_step_fn(current_agent, model, action)

    # Calculate reward using the configured function
    reward = config.reward_fn(model, current_agent, action, initial_state, model)

    #println("DEBUG ENV: Current training agent: $(current_agent.id)")
    #println("DEBUG ENV: About to advance simulation")

    # Advance simulation
    advance_simulation!(model)

    #println("DEBUG ENV: After advance - model time: $(abmtime(model))")
    #println("DEBUG ENV: All agent wealths: $([a.wealth for a in allagents(model)])")

    # Return next state and observation
    sp = s  # Dummy state
    o = POMDPs.observation(wrapper, sp)

    return (sp=sp, o=o, r=reward)
end

"""
    POMDPs.isterminal(wrapper::RLEnvironmentWrapper, s)

Check if the current state is terminal.
"""
function POMDPs.isterminal(wrapper::RLEnvironmentWrapper, s)
    model = wrapper.model
    if isnothing(model.rl_config[])
        error("RL configuration not set. Use set_rl_config! first.")
    end

    config = model.rl_config[]
    max_steps = get(config, :max_steps, 100)

    #println("Terminal: ", config.terminal_fn(model))
    #println("Max steps reached: ", abmtime(model) >= max_steps)

    return config.terminal_fn(model) || abmtime(model) >= max_steps
end

"""
    POMDPs.discount(wrapper::RLEnvironmentWrapper)

Get the discount factor for the current agent type.
"""
function POMDPs.discount(wrapper::RLEnvironmentWrapper)
    model = wrapper.model
    if isnothing(model.rl_config[])
        error("RL configuration not set. Use set_rl_config! first.")
    end

    current_agent_type = get_current_training_agent_type(model)
    config = model.rl_config[]

    if haskey(config, :discount_rates) && haskey(config.discount_rates, current_agent_type)
        return config.discount_rates[current_agent_type]
    else
        return 0.99  # Default discount rate
    end
end

"""
    Crux.state_space(wrapper::RLEnvironmentWrapper)

Get the state space for the current agent type.
"""
function Crux.state_space(wrapper::RLEnvironmentWrapper)
    model = wrapper.model
    if isnothing(model.rl_config[])
        error("RL configuration not set. Use set_rl_config! first.")
    end

    current_agent_type = get_current_training_agent_type(model)
    config = model.rl_config[]

    if haskey(config, :state_spaces) && haskey(config.state_spaces, current_agent_type)
        return config.state_spaces[current_agent_type]
    else
        return Crux.ContinuousSpace((10,))  # Default state space
    end
end

"""
    advance_simulation!(model::ReinforcementLearningABM)

Advance the simulation by one step, handling other agents and environment updates.
"""
function advance_simulation!(model::ReinforcementLearningABM)
    if isnothing(model.rl_config[])
        error("RL configuration not set. Use set_rl_config! first.")
    end

    config = model.rl_config[]
    current_agent_type = get_current_training_agent_type(model)

    # Move to next agent of the training type
    agents_of_type = [a for a in allagents(model) if typeof(a) == current_agent_type]
    #println("Current training agent type: $current_agent_type, agents: $(length(agents_of_type))")

    if !isempty(agents_of_type)
        model.current_training_agent_id[] += 1
        #current_agent_idx = model.current_training_agent_id[]
        #agent_idx = ((current_agent_idx - 1) % length(agents_of_type)) + 1
        #actual_agent = agents_of_type[agent_idx]
        #println("Current training agent index: $current_agent_idx (cycling through agent ID $(actual_agent.id))")

        # If we've cycled through all agents of this type, run other agents and environment step
        if model.current_training_agent_id[] > length(agents_of_type)
            model.current_training_agent_id[] = 1

            # Run other agent types with their policies or random behavior
            training_agent_types = get(config, :training_agent_types, [current_agent_type])
            for agent_type in training_agent_types
                if agent_type != current_agent_type
                    other_agents = [a for a in allagents(model) if typeof(a) == agent_type]

                    for other_agent in other_agents
                        try
                            if haskey(model.trained_policies, agent_type)
                                # Use trained policy
                                obs_radius = get(config, :observation_radius, 2)
                                obs = config.observation_fn(model, other_agent.id, obs_radius)
                                obs_vec = config.observation_to_vector_fn(obs)
                                action = Crux.action(model.trained_policies[agent_type], obs_vec)
                                println("DEBUG ADVANCE: Agent $(other_agent.id) using trained policy, action: $action")
                                config.agent_step_fn(other_agent, model, action)
                            else
                                # Fall back to random behavior
                                if haskey(config.action_spaces, agent_type)
                                    action = rand(config.action_spaces[agent_type].vals)
                                    println("DEBUG ADVANCE: Agent $(other_agent.id) using random action: $action")
                                    config.agent_step_fn(other_agent, model, action)
                                end
                            end
                        catch e
                            # Agent might have died during action, continue
                            continue
                        end
                    end
                end
            end

            # Run model step and increment time
            model.model_step(model)
            model.time[] += 1
        end
    end
end


"""
    step_rl!(model::ReinforcementLearningABM, n::Int=1)

Step the model forward using trained RL policies for agent behavior.
If policies are not available for some agent types, they will use random actions.

Note: This function provides explicit RL stepping. You can also use the standard 
`step!(model, n)` which will automatically use RL policies when available through
the `step_ahead_rl!` infrastructure.
"""
function step_rl!(model::ReinforcementLearningABM, n::Int=1)
    if isnothing(model.rl_config[])
        error("RL configuration not set. Use set_rl_config! first.")
    end

    for _ in 1:n
        # Step agents using RL policies
        for agent in allagents(model)
            rl_agent_step!(agent, model)
        end

        # Step the model
        model.model_step(model)

        # Increment time
        model.time[] += 1
    end
end

"""
    rl_agent_step!(agent, model)

Default agent stepping function for RL agents. This will use trained policies
if available, otherwise fall back to random actions.
"""
function rl_agent_step!(agent, model)
    if model isa ReinforcementLearningABM
        agent_type = typeof(agent)

        if haskey(model.trained_policies, agent_type) && !isnothing(model.rl_config[])
            # Use trained policy
            config = model.rl_config[]
            obs = config.observation_fn(model, agent.id, get(config, :observation_radius, 2))
            obs_vec = config.observation_to_vector_fn(obs)

            # Check if Crux is available before using it
            if isdefined(Main, :Crux)
                action = Main.Crux.action(model.trained_policies[agent_type], obs_vec)
            else
                error("Crux is not available. Please import Crux before using trained RL policies.")
            end

            config.agent_step_fn(agent, model, action[1])
            println("DEBUG RL STEP: Agent $(agent.id) using trained policy, action: $action")
        else
            # Fall back to random behavior
            if !isnothing(model.rl_config[]) && haskey(model.rl_config[].action_spaces, agent_type)
                action_space = model.rl_config[].action_spaces[agent_type]
                action = rand(abmrng(model), action_space.vals)
                model.rl_config[].agent_step_fn(agent, model, action)
                println("DEBUG RL STEP: Agent $(agent.id) using random action: $action")
            else
                # Do nothing if no RL configuration available
                println("DEBUG RL STEP: No RL configuration or action space for agent $(agent.id), skipping step.")
                return
            end
        end
    else
        error("rl_agent_step! can only be used with ReinforcementLearningABM models.")
    end
end


"""
    RLEnvironmentWrapper{M} <: POMDPs.POMDP{Vector{Float32}, Int, Vector{Float32}}

A wrapper around `ReinforcementLearningABM` that implements the POMDPs.POMDP interface
to enable training with RL algorithms that require POMDPs compatibility.

This wrapper serves as a bridge between Agent-Based Models and Reinforcement Learning
algorithms, translating between ABM concepts and RL concepts:

- **States**: ABM state → Vector{Float32} representations
- **Actions**: Discrete integer actions → Agent behaviors  
- **Observations**: Agent-centric views → Vector{Float32} feature vectors
- **Rewards**: Simulation outcomes → Scalar reward signals

## Type Parameters
- `M <: ReinforcementLearningABM`: The type of the wrapped ABM

## Fields
- `model::M`: The wrapped ReinforcementLearningABM instance

## POMDPs Interface
The wrapper implements the complete POMDPs interface including:
- `actions(env)`: Get available actions
- `observations(env)`: Get observation space
- `observation(env, state)`: Generate observations
- `gen(env, state, action, rng)`: State transitions and rewards
- `initialstate(env)`: Episode initialization
- `isterminal(env, state)`: Termination conditions
- `discount(env)`: Discount factor

## Example
```julia
# Create wrapper
env = wrap_for_rl_training(model)

# Use with RL algorithms
solver = PPO(π=policy, S=observations(env), N=10000)
policy = solve(solver, env)
```
"""
struct RLEnvironmentWrapper{M<:ReinforcementLearningABM} <: POMDPs.POMDP{Vector{Float32},Int,Vector{Float32}}
    model::M
end


"""
    wrap_for_rl_training(model::ReinforcementLearningABM) → RLEnvironmentWrapper

Wrap a ReinforcementLearningABM in an RLEnvironmentWrapper to make it compatible
with POMDPs-based RL training algorithms.

## Arguments
- `model::ReinforcementLearningABM`: The ReinforcementLearningABM to wrap

## Returns
- `RLEnvironmentWrapper`: A wrapper that implements the POMDPs.POMDP interface

## Notes
This wrapper enables the use of standard RL algorithms (PPO, DQN, A2C) with ABMs by:
- Translating ABM states to RL observations
- Mapping RL actions to agent behaviors
- Computing rewards based on simulation outcomes
- Managing episode termination conditions

The wrapper automatically handles agent cycling, multi-agent coordination, and
integrates with the configured observation, reward, and terminal functions.

## Example
```julia
# Set up RL configuration
config = (
    observation_fn = my_obs_function,
    reward_fn = my_reward_function,
    terminal_fn = my_terminal_function,
    action_spaces = Dict(MyAgent => Crux.DiscreteSpace(4)),
    observation_spaces = Dict(MyAgent => Crux.ContinuousSpace((10,), Float32)),
    # ... other config
)

# Create and configure model
model = ReinforcementLearningABM(MyAgent, GridSpace((5, 5)))
set_rl_config!(model, config)

# Wrap for training
env = wrap_for_rl_training(model)

# Use with standard RL algorithms
solver = PPO(π=policy, S=observations(env), N=1000)
trained_policy = solve(solver, env)
```
"""
function wrap_for_rl_training(model::ReinforcementLearningABM)
    return RLEnvironmentWrapper(model)
end

"""
    POMDPs.actions(wrapper::RLEnvironmentWrapper) → ActionSpace

Get the action space for the currently training agent type.

## Arguments
- `wrapper::RLEnvironmentWrapper`: The wrapped RL environment

## Returns
- `ActionSpace`: The action space (e.g., Crux.DiscreteSpace) for the current agent type

## Throws
- `ErrorException`: If RL configuration is not set or no action space is defined for the agent type

## Notes
This function is part of the POMDPs interface and is called automatically during training
to determine what actions are available to the agent.
"""
function POMDPs.actions(wrapper::RLEnvironmentWrapper)
    model = wrapper.model
    if isnothing(model.rl_config[])
        error("RL configuration not set. Use set_rl_config! first.")
    end

    current_agent_type = Agents.get_current_training_agent_type(model)
    config = model.rl_config[]

    if haskey(config.action_spaces, current_agent_type)
        return config.action_spaces[current_agent_type]
    else
        error("No action space defined for agent type $current_agent_type")
    end
end

"""
    POMDPs.observations(wrapper::RLEnvironmentWrapper) → ObservationSpace

Get the observation space for the currently training agent type.

## Arguments
- `wrapper::RLEnvironmentWrapper`: The wrapped RL environment

## Returns
- `ObservationSpace`: The observation space (e.g., Crux.ContinuousSpace) for the current agent type

## Notes
This function is part of the POMDPs interface. If no observation space is defined for the
agent type, it returns a default ContinuousSpace with 10 dimensions and issues a warning.

## Example
```julia
env = wrap_for_rl_training(model)
obs_space = POMDPs.observations(env)
println("Observation dimensions: ", Crux.dim(obs_space))
```
"""
function POMDPs.observations(wrapper::RLEnvironmentWrapper)
    model = wrapper.model
    if isnothing(model.rl_config[])
        error("RL configuration not set. Use set_rl_config! first.")
    end

    current_agent_type = Agents.get_current_training_agent_type(model)
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
    POMDPs.observation(wrapper::RLEnvironmentWrapper, s::Vector{Float32}) → Vector{Float32}

Get the observation for the current training agent.

## Arguments
- `wrapper::RLEnvironmentWrapper`: The wrapped RL environment
- `s::Vector{Float32}`: The current state (typically unused in ABM context)

## Returns
- `Vector{Float32}`: The observation vector for the current training agent

## Notes
This function uses the configured observation function to generate observation vectors
for the current training agent. If no agent is currently being trained, it returns a 
zero vector with appropriate dimensions.

## Example
```julia
env = wrap_for_rl_training(model)
state = zeros(Float32, 10)
obs = POMDPs.observation(env, state)
println("Observation: ", obs)
```
"""
function POMDPs.observation(wrapper::RLEnvironmentWrapper, s::Vector{Float32})
    model = wrapper.model
    if isnothing(model.rl_config[])
        error("RL configuration not set. Use set_rl_config! first.")
    end

    current_agent = Agents.get_current_training_agent(model)
    if isnothing(current_agent)
        # Return zero observation with correct dimensions
        obs_space = POMDPs.observations(wrapper)
        obs_dims = Crux.dim(obs_space)
        return zeros(Float32, obs_dims...)
    end

    config = model.rl_config[]
    obs_radius = get(config, :observation_radius, 2)

    # Get observation vector directly from the configured function
    return config.observation_fn(model, current_agent.id, obs_radius)
end

"""
    POMDPs.initialstate(wrapper::RLEnvironmentWrapper) → Dirac{Vector{Float32}}

Initialize the state for a new episode.

## Arguments
- `wrapper::RLEnvironmentWrapper`: The wrapped RL environment

## Returns
- `Dirac{Vector{Float32}}`: A deterministic distribution over initial states

## Notes
This function resets the model to its initial state using `reset_model_for_episode!`
and returns a deterministic initial state distribution. The state dimensions are
determined from the RL configuration or default to 10 dimensions.

## Example
```julia
env = wrap_for_rl_training(model)
initial_state_dist = POMDPs.initialstate(env)
initial_state = rand(initial_state_dist)
```
"""
function POMDPs.initialstate(wrapper::RLEnvironmentWrapper)
    model = wrapper.model
    if isnothing(model.rl_config[])
        error("RL configuration not set. Use set_rl_config! first.")
    end

    #println("DEBUG RESET: Resetting model for new episode")

    # Reset the model to initial state
    Agents.reset_model_for_episode!(model)

    #println("DEBUG RESET: Model reset complete, time: $(abmtime(model)), training agent ID: $(model.current_training_agent_id[])")

    # Return initial state
    current_agent_type = Agents.get_current_training_agent_type(model)
    config = model.rl_config[]

    if haskey(config, :state_spaces) && haskey(config.state_spaces, current_agent_type)
        state_dims = Crux.dim(config.state_spaces[current_agent_type])
    else
        state_dims = (10,)  # Default state dimensions
    end

    return Dirac(zeros(Float32, state_dims...))
end

"""
    POMDPs.initialobs(wrapper::RLEnvironmentWrapper, initial_state::Vector{Float32}) → Dirac{Vector{Float32}}

Get the initial observation for a new episode.

## Arguments
- `wrapper::RLEnvironmentWrapper`: The wrapped RL environment
- `initial_state::Vector{Float32}`: The initial state vector

## Returns
- `Dirac{Vector{Float32}}`: A deterministic distribution over initial observations

## Notes
This function generates the initial observation for a new episode by calling
`POMDPs.observation` with the initial state and wrapping the result in a
deterministic distribution.

## Example
```julia
env = wrap_for_rl_training(model)
initial_state = zeros(Float32, 10)
initial_obs_dist = POMDPs.initialobs(env, initial_state)
initial_obs = rand(initial_obs_dist)
```
"""
function POMDPs.initialobs(wrapper::RLEnvironmentWrapper, initial_state::Vector{Float32})
    obs = POMDPs.observation(wrapper, initial_state)
    return Dirac(obs)
end

"""
    POMDPs.gen(wrapper::RLEnvironmentWrapper, s, action::Int, rng::AbstractRNG) → NamedTuple

Generate the next state, observation, and reward after taking an action.

## Arguments
- `wrapper::RLEnvironmentWrapper`: The wrapped RL environment
- `s`: The current state
- `action::Int`: The action to take
- `rng::AbstractRNG`: Random number generator (typically unused)

## Returns
- `NamedTuple`: A named tuple with fields:
  - `sp`: Next state (same as input state in ABM context)
  - `o::Vector{Float32}`: Next observation vector
  - `r::Float32`: Reward for the action

## Notes
This is the core POMDPs interface function that:
1. Executes the action using the configured agent stepping function
2. Calculates the reward using the configured reward function
3. Advances the simulation to handle other agents and environment updates
4. Returns the next observation

If no current training agent exists, returns a terminal state with -10.0 reward.

## Example
```julia
env = wrap_for_rl_training(model)
state = zeros(Float32, 10)
action = 1
result = POMDPs.gen(env, state, action, Random.default_rng())
println("Reward: ", result.r)
```
"""
function POMDPs.gen(wrapper::RLEnvironmentWrapper, s, action::Int, rng::AbstractRNG)
    model = wrapper.model
    if isnothing(model.rl_config[])
        error("RL configuration not set. Use set_rl_config! first.")
    end

    current_agent = Agents.get_current_training_agent(model)

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
    POMDPs.isterminal(wrapper::RLEnvironmentWrapper, s) → Bool

Check if the current state is terminal.

## Arguments
- `wrapper::RLEnvironmentWrapper`: The wrapped RL environment
- `s`: The current state

## Returns
- `Bool`: `true` if the episode should terminate, `false` otherwise

## Notes
An episode terminates if:
1. The configured terminal function returns `true`, OR
2. The model time has reached the maximum steps configured in RL config

The maximum steps default to 100 if not specified in the configuration.

## Example
```julia
env = wrap_for_rl_training(model)
state = zeros(Float32, 10)
is_done = POMDPs.isterminal(env, state)
println("Episode terminated: ", is_done)
```
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
    POMDPs.discount(wrapper::RLEnvironmentWrapper) → Float64

Get the discount factor for the current agent type.

## Arguments
- `wrapper::RLEnvironmentWrapper`: The wrapped RL environment

## Returns
- `Float64`: The discount factor (gamma) for the current training agent type

## Notes
The discount factor is looked up from the RL configuration's `discount_rates` dictionary
using the current training agent type as the key. If not found, defaults to 0.99.

## Example
```julia
env = wrap_for_rl_training(model)
γ = POMDPs.discount(env)
println("Discount factor: ", γ)
```
"""
function POMDPs.discount(wrapper::RLEnvironmentWrapper)
    model = wrapper.model
    if isnothing(model.rl_config[])
        error("RL configuration not set. Use set_rl_config! first.")
    end

    current_agent_type = Agents.get_current_training_agent_type(model)
    config = model.rl_config[]

    if haskey(config, :discount_rates) && haskey(config.discount_rates, current_agent_type)
        return config.discount_rates[current_agent_type]
    else
        return 0.99  # Default discount rate
    end
end

"""
    Crux.state_space(wrapper::RLEnvironmentWrapper) → StateSpace

Get the state space for the current agent type.

## Arguments
- `wrapper::RLEnvironmentWrapper`: The wrapped RL environment

## Returns
- `StateSpace`: The state space (e.g., Crux.ContinuousSpace) for the current agent type

## Notes
This function looks up the state space from the RL configuration's `state_spaces` dictionary.
If not found, defaults to a ContinuousSpace with 10 dimensions. This is part of the
Crux.jl interface extension.

## Example
```julia
env = wrap_for_rl_training(model)
state_space = Crux.state_space(env)
println("State dimensions: ", Crux.dim(state_space))
```
"""
function Crux.state_space(wrapper::RLEnvironmentWrapper)
    model = wrapper.model
    if isnothing(model.rl_config[])
        error("RL configuration not set. Use set_rl_config! first.")
    end

    current_agent_type = Agents.get_current_training_agent_type(model)
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

## Arguments
- `model::ReinforcementLearningABM`: The RL model to advance

## Notes
This function implements the core simulation advancement logic:

1. **Agent Cycling**: Moves to the next agent of the current training type
2. **Multi-Agent Coordination**: When all training agents have acted, runs other agent types
3. **Policy Application**: Uses trained policies for other agents when available, falls back to random actions
4. **Environment Step**: Executes the model stepping function and increments time

The function handles agent removal (agents that die during actions) and ensures
proper coordination between different agent types during training.
"""
function advance_simulation!(model::ReinforcementLearningABM)
    if isnothing(model.rl_config[])
        error("RL configuration not set. Use set_rl_config! first.")
    end

    config = model.rl_config[]
    current_agent_type = Agents.get_current_training_agent_type(model)

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
                                obs_vec = config.observation_fn(model, other_agent.id, obs_radius)
                                action = Crux.action(model.trained_policies[agent_type], obs_vec)
                                #println("DEBUG ADVANCE: Agent $(other_agent.id) using trained policy, action: $action")
                                config.agent_step_fn(other_agent, model, action)
                            else
                                # Fall back to random behavior
                                if haskey(config.action_spaces, agent_type)
                                    action = rand(config.action_spaces[agent_type].vals)
                                    #println("DEBUG ADVANCE: Agent $(other_agent.id) using random action: $action")
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
using POMDPs
using Crux
using Flux
using Distributions
using Random

"""
    AbstractRLAgent

Abstract type for agents that can be trained using reinforcement learning.
"""
abstract type AbstractRLAgent end

"""
    AbstractRLEnvironment{S,A,O} <: POMDP{S,A,O}

Abstract type for RL environments that wrap ABM models.
- S: State type
- A: Action type  
- O: Observation type
"""
abstract type AbstractRLEnvironment{S,A,O} <: POMDP{S,A,O} end


"""
    rl_step!(agent, model, action)

Execute an RL action for the given agent in the model.
This method should be implemented for each agent type that supports RL training.
"""
function rl_step! end

"""
    get_observation(model, agent_id, observation_radius)

Get the local observation for a specific agent in the model.
Returns an observation structure containing relevant local information.
"""
function get_observation end

"""
    observation_to_vector(observation)

Convert an observation structure to a vector that can be used by neural networks.
"""
function observation_to_vector end

"""
    calculate_reward(env, agent, action, initial_state, final_state)

Calculate the reward for an agent's action based on the environment state change.
"""
function calculate_reward end


"""
    GenericRLEnvironment{S,A,O} <: AbstractRLEnvironment{S,A,O}

A generic RL environment that can wrap any ABM model for RL training.
"""
mutable struct GenericRLEnvironment{S,A,O} <: AbstractRLEnvironment{S,A,O}
    abm_model::ABM
    model_init_fn::Function          # Function to initialize the model
    agent_step_fn::Function          # Function for agent RL stepping
    observation_fn::Function        # Function to get observations
    observation_to_vector_fn::Function # Function to convert observations to vectors
    reward_fn::Function             # Function to calculate rewards
    terminal_fn::Function           # Function to check terminal states

    # Environment parameters
    max_steps::Int
    observation_radius::Int
    current_agent_id::Int
    current_agent_type::Type
    step_count::Int

    # Training configuration
    training_agent_types::Vector{Type}
    agent_policies::Dict{Type,Any}
    action_spaces::Dict{Type,Any}
    observation_spaces::Dict{Type,Any}
    state_spaces::Dict{Type,Any}
    discount_rates::Dict{Type,Float64}

    # RNG
    rng::AbstractRNG

    # Model-specific parameters
    model_params::Dict{Symbol,Any}
end

"""
    GenericRLEnvironment(;
        model_init_fn,
        agent_step_fn, 
        observation_fn,
        observation_to_vector_fn,
        reward_fn,
        terminal_fn,
        training_agent_types,
        action_spaces,
        observation_spaces=Dict(),
        state_spaces=Dict(),
        discount_rates=Dict(),
        max_steps=1000,
        observation_radius=2,
        seed=123,
        model_params=Dict()
    )

Constructor for a generic RL environment.
"""
function GenericRLEnvironment(;
    model_init_fn,
    agent_step_fn,
    observation_fn,
    observation_to_vector_fn,
    reward_fn,
    terminal_fn,
    training_agent_types,
    action_spaces,
    observation_spaces=Dict(),
    state_spaces=Dict(),
    discount_rates=Dict(),
    max_steps=1000,
    observation_radius=2,
    seed=123,
    model_params=Dict()
)
    rng = MersenneTwister(seed)

    # Initialize the model
    model = model_init_fn(; model_params..., seed=seed)

    # Set default observation and state spaces if not provided
    default_obs_space = Crux.ContinuousSpace((100,), Float32)
    default_state_space = Crux.ContinuousSpace((10,))
    default_discount = 0.99

    obs_spaces = Dict{Type,Any}()
    s_spaces = Dict{Type,Any}()
    discounts = Dict{Type,Float64}()

    for agent_type in training_agent_types
        obs_spaces[agent_type] = get(observation_spaces, agent_type, default_obs_space)
        s_spaces[agent_type] = get(state_spaces, agent_type, default_state_space)
        discounts[agent_type] = get(discount_rates, agent_type, default_discount)
    end

    # Set up the environment
    env = GenericRLEnvironment{Vector{Float32},Int,Vector{Float32}}(
        model,
        model_init_fn,
        agent_step_fn,
        observation_fn,
        observation_to_vector_fn,
        reward_fn,
        terminal_fn,
        max_steps,
        observation_radius,
        1,
        training_agent_types[1],
        0,
        training_agent_types,
        Dict{Type,Any}(),
        action_spaces,
        obs_spaces,
        s_spaces,
        discounts,
        rng,
        model_params
    )

    return env
end

## POMDPs.jl Interface Implementation
function POMDPs.actions(env::GenericRLEnvironment)
    return env.action_spaces[env.current_agent_type]
end

function POMDPs.observations(env::GenericRLEnvironment)
    return env.observation_spaces[env.current_agent_type]
end

function POMDPs.observation(env::GenericRLEnvironment, s::Vector{Float32})
    # Get current agent for training
    current_agent = get_current_training_agent(env)
    if isnothing(current_agent)
        # Return zero observation with correct dimensions
        obs_dims = Crux.dim(env.observation_spaces[env.current_agent_type])
        return zeros(Float32, obs_dims...)
    end

    # Get observation using the provided function
    obs = env.observation_fn(env.abm_model, current_agent.id, env.observation_radius)
    return env.observation_to_vector_fn(obs)
end

function POMDPs.initialstate(env::GenericRLEnvironment)
    # Reset the model
    env.abm_model = env.model_init_fn(; env.model_params..., seed=rand(env.rng, Int))
    env.current_agent_id = 1
    env.step_count = 0

    # Return dummy state with correct dimensions
    state_dims = Crux.dim(env.state_spaces[env.current_agent_type])
    return Dirac(zeros(Float32, state_dims...))
end

function POMDPs.initialobs(env::GenericRLEnvironment, initial_state::Vector{Float32})
    obs = POMDPs.observation(env, initial_state)
    return Dirac(obs)
end

function POMDPs.gen(env::GenericRLEnvironment, s, action::Int, rng::AbstractRNG)
    current_agent = get_current_training_agent(env)

    if isnothing(current_agent)
        # Episode terminated
        obs_dims = Crux.dim(env.observation_spaces[env.current_agent_type])
        return (sp=s, o=zeros(Float32, obs_dims...), r=-10.0)
    end

    # Record initial state for reward calculation
    initial_state = deepcopy(env.abm_model)

    # Execute the action using the provided stepping function
    env.agent_step_fn(current_agent, env.abm_model, action)

    # Calculate reward using the provided function
    reward = env.reward_fn(env, current_agent, action, initial_state, env.abm_model)

    # Advance simulation
    advance_simulation(env)

    # Return next state and observation
    sp = s  # Dummy state
    o = observation(env, sp)

    return (sp=sp, o=o, r=reward)
end

function POMDPs.isterminal(env::GenericRLEnvironment, s)
    return env.terminal_fn(env) || env.step_count >= env.max_steps
end

function get_current_training_agent(env::GenericRLEnvironment)
    agents_of_type = [a for a in allagents(env.abm_model) if typeof(a) == env.current_agent_type]

    if isempty(agents_of_type)
        return nothing
    end

    # Cycle through agents of the training type
    agent_idx = ((env.current_agent_id - 1) % length(agents_of_type)) + 1
    return agents_of_type[agent_idx]
end

function advance_simulation(env::GenericRLEnvironment)
    # Move to next agent of the training type
    agents_of_type = [a for a in allagents(env.abm_model) if typeof(a) == env.current_agent_type]

    if !isempty(agents_of_type)
        env.current_agent_id += 1

        # If we've cycled through all agents of this type, run other agents and environment step
        if env.current_agent_id > length(agents_of_type)
            env.current_agent_id = 1

            # Run other agent types with their policies or random behavior
            for agent_type in env.training_agent_types
                if agent_type != env.current_agent_type
                    other_agents = [a for a in allagents(env.abm_model) if typeof(a) == agent_type]

                    for other_agent in other_agents
                        try
                            if haskey(env.agent_policies, agent_type)
                                # Use trained policy
                                obs = env.observation_fn(env.abm_model, other_agent.id, env.observation_radius)
                                obs_vec = env.observation_to_vector_fn(obs)
                                action = Crux.action(env.agent_policies[agent_type], obs_vec)
                                env.agent_step_fn(other_agent, env.abm_model, action)
                            else
                                # Fall back to random behavior
                                action = rand(env.action_spaces[agent_type].vals)
                                env.agent_step_fn(other_agent, env.abm_model, action)
                            end
                        catch e
                            # Agent might have died during action, continue
                            continue
                        end
                    end
                end
            end

            env.step_count += 1
        end
    end
end

Crux.state_space(env::GenericRLEnvironment) = env.state_spaces[env.current_agent_type]
POMDPs.discount(env::GenericRLEnvironment) = env.discount_rates[env.current_agent_type]

"""
    setup_rl_training(agent_type, env_config; 
        training_steps=50_000,
        value_network=nothing,
        policy_network=nothing,
        solver=nothing,
        solver_type=:PPO,
        solver_params=Dict()
    )

Set up RL training for a specific agent type with the given environment configuration.
"""
function setup_rl_training(agent_type, env_config;
    training_steps=50_000,
    value_network=nothing,
    policy_network=nothing,
    solver=nothing,
    solver_type=:PPO,
    solver_params=Dict()
)
    # Create environment for training the specified agent type
    env = GenericRLEnvironment(; env_config..., training_agent_types=[agent_type])

    # Set current training type
    env.current_agent_type = agent_type

    # If a complete solver is provided, use it directly
    if !isnothing(solver)
        return env, solver
    end

    # Get observation and action spaces
    O = observations(env)
    as = POMDPs.actions(env).vals

    # Define neural network architecture
    if isnothing(value_network)
        V() = ContinuousNetwork(Chain(Dense(Crux.dim(O)..., 64, relu), Dense(64, 64, relu), Dense(64, 1)))
    else
        V = value_network
    end

    if isnothing(policy_network)
        B() = DiscreteNetwork(Chain(Dense(Crux.dim(O)..., 64, relu), Dense(64, 64, relu), Dense(64, length(as))), as)
    else
        B = policy_network
    end

    # Create solver based on type
    if solver_type == :PPO
        default_params = Dict(
            :π => ActorCritic(B(), V()),
            :S => O,
            :N => training_steps,
            :ΔN => 500,
            :log => (period=1000,)
        )
        merged_params = merge(default_params, solver_params)
        solver = PPO(; merged_params...)
    elseif solver_type == :DQN
        if isnothing(policy_network)
            QS() = DiscreteNetwork(
                Chain(
                    Dense(Crux.dim(O)[1], 64, relu),
                    Dense(64, 64, relu),
                    Dense(64, length(as))
                ), as
            )
        else
            QS = policy_network
        end
        default_params = Dict(
            :π => QS(),
            :S => O,
            :N => training_steps,
            :buffer_size => 10000,
            :buffer_init => 1000,
            :ΔN => 50
        )
        merged_params = merge(default_params, solver_params)
        solver = DQN(; merged_params...)
    elseif solver_type == :A2C
        default_params = Dict(
            :π => ActorCritic(B(), V()),
            :S => O,
            :N => training_steps,
            :ΔN => 20,
            :log => (period=1000,)
        )
        merged_params = merge(default_params, solver_params)
        solver = A2C(; merged_params...)
    else
        error("Unsupported solver type: $solver_type.")
    end

    return env, solver
end

"""
    train_agent_sequential(agent_types, env_config; 
        training_steps=50_000,
        custom_networks=Dict(),
        custom_solvers=Dict(),
        solver_types=Dict(),
        solver_params=Dict()
    )

Train multiple agent types sequentially, where each subsequent agent is trained
against the previously trained agents.
"""
function train_agent_sequential(agent_types, env_config;
    training_steps=50_000,
    custom_networks=Dict(),
    custom_solvers=Dict(),
    solver_types=Dict(),
    solver_params=Dict()
)
    println("Training agents sequentially...")

    policies = Dict{Type,Any}()
    solvers = Dict{Type,Any}()

    for (i, agent_type) in enumerate(agent_types)
        println("Training $(agent_type) ($(i)/$(length(agent_types)))...")

        # Get custom parameters for this agent type
        agent_networks = get(custom_networks, agent_type, Dict())
        value_net = get(agent_networks, :value_network, nothing)
        policy_net = get(agent_networks, :policy_network, nothing)
        custom_solver = get(custom_solvers, agent_type, nothing)
        solver_type = get(solver_types, agent_type, :PPO)
        solver_params_agent = get(solver_params, agent_type, Dict())

        # Set up training environment
        env, solver = setup_rl_training(
            agent_type,
            env_config;
            training_steps=training_steps,
            value_network=value_net,
            policy_network=policy_net,
            solver=custom_solver,
            solver_type=solver_type,
            solver_params=solver_params_agent
        )

        # Add previously trained policies
        for (prev_type, policy) in policies
            env.agent_policies[prev_type] = policy
        end

        # Train the agent
        policy = solve(solver, env)
        policies[agent_type] = policy
        solvers[agent_type] = solver

        println("Completed training $(agent_type)")
    end

    return policies, solvers
end

"""
    train_agent_simultaneous(agent_types, env_config; 
        n_iterations=5, 
        batch_size=10_000,
        custom_networks=Dict(),
        custom_solvers=Dict(),
        solver_types=Dict(),
        solver_params=Dict()
    )

Train multiple agent types simultaneously with alternating batch updates.
"""
function train_agent_simultaneous(agent_types, env_config;
    n_iterations=5,
    batch_size=10_000,
    custom_networks=Dict(),
    custom_solvers=Dict(),
    solver_types=Dict(),
    solver_params=Dict()
)
    println("Training agents simultaneously...")

    # Initialize environments and solvers for each agent type
    envs = Dict{Type,Any}()
    solvers = Dict{Type,Any}()

    for agent_type in agent_types
        # Get custom parameters for this agent type
        agent_networks = get(custom_networks, agent_type, Dict())
        value_net = get(agent_networks, :value_network, nothing)
        policy_net = get(agent_networks, :policy_network, nothing)
        custom_solver = get(custom_solvers, agent_type, nothing)
        solver_type = get(solver_types, agent_type, :PPO)
        solver_params_agent = get(solver_params, agent_type, Dict())

        env, solver = setup_rl_training(
            agent_type,
            env_config;
            training_steps=batch_size,
            value_network=value_net,
            policy_network=policy_net,
            solver=custom_solver,
            solver_type=solver_type,
            solver_params=solver_params_agent
        )

        envs[agent_type] = env
        solvers[agent_type] = solver
    end

    policies = Dict{Type,Any}()

    # Train in alternating batches
    for iter in 1:n_iterations
        println("Iteration $(iter)/$(n_iterations)")

        for agent_type in agent_types
            println("  Training $(agent_type)...")

            # Update environment with current policies
            for (other_type, policy) in policies
                if other_type != agent_type
                    envs[agent_type].agent_policies[other_type] = policy
                end
            end

            # Train the agent
            policy = solve(solvers[agent_type], envs[agent_type])
            policies[agent_type] = policy
        end
    end

    return policies, solvers
end

## Helper Functions for Custom Neural Networks
"""
    create_value_network(input_dims, hidden_layers=[64, 64], activation=relu)

Create a custom value network with specified architecture.
"""
function create_value_network(input_dims, hidden_layers=[64, 64], activation=relu)
    layers = []

    # Input layer
    push!(layers, Dense(input_dims..., hidden_layers[1], activation))

    # Hidden layers
    for i in 1:(length(hidden_layers)-1)
        push!(layers, Dense(hidden_layers[i], hidden_layers[i+1], activation))
    end

    # Output layer
    push!(layers, Dense(hidden_layers[end], 1))

    return () -> ContinuousNetwork(Chain(layers...))
end

"""
    create_policy_network(input_dims, output_dims, action_space, hidden_layers=[64, 64], activation=relu)

Create a custom policy network with specified architecture.
"""
function create_policy_network(input_dims, output_dims, action_space, hidden_layers=[64, 64], activation=relu)
    layers = []

    # Input layer
    push!(layers, Dense(input_dims..., hidden_layers[1], activation))

    # Hidden layers
    for i in 1:(length(hidden_layers)-1)
        push!(layers, Dense(hidden_layers[i], hidden_layers[i+1], activation))
    end

    # Output layer
    push!(layers, Dense(hidden_layers[end], output_dims))

    return () -> DiscreteNetwork(Chain(layers...), action_space)
end

"""
    create_custom_solver(solver_type, custom_params)

Create a custom solver with specified parameters.
"""
function create_custom_solver(solver_type, π, S; custom_params...)
    if solver_type == :PPO
        return PPO(π=π, S=S; custom_params...)
    elseif solver_type == :DQN
        return DQN(π=π, S=S; custom_params...)
    elseif solver_type == :A2C
        return A2C(π=π, S=S; custom_params...)
    else
        error("Unsupported solver type: $solver_type")
    end
end
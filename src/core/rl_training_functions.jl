using POMDPs
using Crux

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
    setup_rl_training(model::ReinforcementLearningABM, agent_type; 
        training_steps=50_000,
        value_network=nothing,
        policy_network=nothing,
        solver=nothing,
        solver_type=:PPO,
        solver_params=Dict()
    )

Set up RL training for a specific agent type using the ReinforcementLearningABM directly.
Returns a wrapped environment compatible with POMDPs training algorithms.
"""
function setup_rl_training(model::ReinforcementLearningABM, agent_type;
    training_steps=50_000,
    value_network=nothing,
    policy_network=nothing,
    solver=nothing,
    solver_type=:PPO,
    solver_params=Dict()
)
    if isnothing(model.rl_config[])
        error("RL configuration not set. Use set_rl_config! first.")
    end

    # Set the current training agent type in the model
    model.current_training_agent_type[] = agent_type

    # Wrap the model for POMDPs compatibility
    env = wrap_for_rl_training(model)

    # If a complete solver is provided, use it directly
    if !isnothing(solver)
        return env, solver
    end

    # Get observation and action spaces
    O = POMDPs.observations(env)
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
    train_agent_sequential(model::ReinforcementLearningABM, agent_types; 
        training_steps=50_000,
        custom_networks=Dict(),
        custom_solvers=Dict(),
        solver_types=Dict(),
        solver_params=Dict()
    )

Train multiple agent types sequentially using the ReinforcementLearningABM, where each 
subsequent agent is trained against the previously trained agents.
"""
function train_agent_sequential(model::ReinforcementLearningABM, agent_types;
    training_steps=50_000,
    custom_networks=Dict(),
    custom_solvers=Dict(),
    solver_types=Dict(),
    solver_params=Dict()
)
    println("Training agents sequentially...")

    # Ensure agent_types is a vector
    agent_types_vec = agent_types isa Vector ? agent_types : [agent_types]

    policies = Dict{Type,Any}()
    solvers = Dict{Type,Any}()

    for (i, agent_type) in enumerate(agent_types_vec)
        println("Training $(agent_type) ($(i)/$(length(agent_types_vec)))...")

        # Get custom parameters for this agent type
        agent_networks = get(custom_networks, agent_type, Dict())
        value_net = get(agent_networks, :value_network, nothing)
        policy_net = get(agent_networks, :policy_network, nothing)
        custom_solver = get(custom_solvers, agent_type, nothing)
        solver_type = get(solver_types, agent_type, :PPO)
        solver_params_agent = get(solver_params, agent_type, Dict())

        # Set up training 
        env, solver = setup_rl_training(
            model,
            agent_type;
            training_steps=training_steps,
            value_network=value_net,
            policy_network=policy_net,
            solver=custom_solver,
            solver_type=solver_type,
            solver_params=solver_params_agent
        )

        # Add previously trained policies to the model
        for (prev_type, policy) in policies
            model.trained_policies[prev_type] = policy
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
    train_agent_simultaneous(model::ReinforcementLearningABM, agent_types; 
        n_iterations=5, 
        batch_size=10_000,
        custom_networks=Dict(),
        custom_solvers=Dict(),
        solver_types=Dict(),
        solver_params=Dict()
    )

Train multiple agent types simultaneously using the ReinforcementLearningABM with 
alternating batch updates.
"""
function train_agent_simultaneous(model::ReinforcementLearningABM, agent_types;
    n_iterations=5,
    batch_size=10_000,
    custom_networks=Dict(),
    custom_solvers=Dict(),
    solver_types=Dict(),
    solver_params=Dict()
)
    println("Training agents simultaneously...")

    # Ensure agent_types is a vector
    agent_types_vec = agent_types isa Vector ? agent_types : [agent_types]

    # Initialize solvers for each agent type
    solvers = Dict{Type,Any}()
    envs = Dict{Type,Any}()

    for agent_type in agent_types_vec
        # Get custom parameters for this agent type
        agent_networks = get(custom_networks, agent_type, Dict())
        value_net = get(agent_networks, :value_network, nothing)
        policy_net = get(agent_networks, :policy_network, nothing)
        custom_solver = get(custom_solvers, agent_type, nothing)
        solver_type = get(solver_types, agent_type, :PPO)
        solver_params_agent = get(solver_params, agent_type, Dict())

        # Create a separate model instance for each agent type's training
        training_model = create_training_model_copy(model)

        env, solver = setup_rl_training(
            training_model,
            agent_type;
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

        for agent_type in agent_types_vec
            println("  Training $(agent_type)...")

            # Update model with current policies
            for (other_type, policy) in policies
                if other_type != agent_type
                    envs[agent_type].model.trained_policies[other_type] = policy
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


"""
    train_model!(model::ReinforcementLearningABM, agent_types; 
                training_mode=:sequential, kwargs...)

Train the specified agent types in the model using reinforcement learning.

## Arguments
- `model`: The ReinforcementLearningABM to train
- `agent_types`: Agent type or vector of agent types to train

## Keyword Arguments  
- `training_mode`: `:sequential` or `:simultaneous` (default: `:sequential`)
- `training_steps`: Number of training steps per agent (default: 50_000)
- `solver_type`: Type of RL solver to use (`:PPO`, `:DQN`, `:A2C`) (default: `:PPO`)
- `custom_networks`: Dict of custom neural networks for each agent type
- `custom_solvers`: Dict of custom solvers for each agent type
- `solver_params`: Dict of custom solver parameters for each agent type
- Other arguments passed to the training functions
"""
function train_model!(model::ReinforcementLearningABM, agent_types;
    training_mode::Symbol=:sequential,
    kwargs...)

    if isnothing(model.rl_config[])
        error("RL configuration not set. Use set_rl_config! first.")
    end

    # Ensure agent_types is a vector
    agent_types_vec = agent_types isa Vector ? agent_types : [agent_types]

    # Set training flag
    model.is_training[] = true

    try
        # Train agents based on mode
        if training_mode == :sequential
            policies, solvers = train_agent_sequential(model, agent_types_vec; kwargs...)
        elseif training_mode == :simultaneous
            policies, solvers = train_agent_simultaneous(model, agent_types_vec; kwargs...)
        else
            error("Unknown training mode: $training_mode. Use :sequential or :simultaneous.")
        end

        # Store trained policies
        for (agent_type, policy) in policies
            model.trained_policies[agent_type] = policy
        end

        # Store training history (solvers)
        for (agent_type, solver) in solvers
            model.training_history[agent_type] = solver
        end

        println("Training completed for agent types: $(join(string.(agent_types_vec), ", "))")

    finally
        model.is_training[] = false
    end

    return model
end

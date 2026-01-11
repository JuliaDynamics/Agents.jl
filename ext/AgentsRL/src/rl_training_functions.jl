function Agents.setup_rl_training(model::ReinforcementLearningABM, agent_type;
    training_steps=50_000,
    max_steps=100,
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
        value_net = ContinuousNetwork(Chain(Dense(Crux.dim(O)..., 64, relu), Dense(64, 64, relu), Dense(64, 1)))
    else
        value_net = value_network()
    end

    if isnothing(policy_network)
        policy_net = DiscreteNetwork(Chain(Dense(Crux.dim(O)..., 64, relu), Dense(64, 64, relu), Dense(64, length(as))), as)
    else
        policy_net = policy_network()
    end

    # Create solver based on type
    if solver_type == :PPO
        default_params = Dict(
            :π => ActorCritic(policy_net, value_net),
            :S => O,
            :N => training_steps,
            :ΔN => 200,
            :max_steps => max_steps,
            :log => (period=1000,)
        )
        merged_params = merge(default_params, solver_params)
        solver = PPO(; merged_params...)
    elseif solver_type == :DQN
        if isnothing(policy_network)
            QS_net = DiscreteNetwork(
                Chain(
                    Dense(Crux.dim(O)[1], 64, relu),
                    Dense(64, 64, relu),
                    Dense(64, length(as))
                ), as
            )
        else
            QS_net = policy_network()
        end
        default_params = Dict(
            :π => QS_net,
            :S => O,
            :N => training_steps,
            :max_steps => max_steps,
            :buffer_size => 10000,
            :buffer_init => 1000,
            :ΔN => 50
        )
        merged_params = merge(default_params, solver_params)
        solver = DQN(; merged_params...)
    elseif solver_type == :A2C
        default_params = Dict(
            :π => ActorCritic(policy_net, value_net),
            :S => O,
            :N => training_steps,
            :ΔN => 20,
            :max_steps => max_steps,
            :log => (period=1000,)
        )
        merged_params = merge(default_params, solver_params)
        solver = A2C(; merged_params...)
    else
        error("Unsupported solver type: $solver_type.")
    end

    return env, solver
end

function Agents.train_agent_sequential(model::ReinforcementLearningABM, agent_types;
    training_steps=50_000,
    max_steps=100,
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
        solver_params_agent = Agents.process_solver_params(solver_params, agent_type)

        # Set up training 
        env, solver = Agents.setup_rl_training(
            model,
            agent_type;
            training_steps=training_steps,
            max_steps=max_steps,
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

function Agents.train_agent_simultaneous(model::ReinforcementLearningABM, agent_types;
    n_iterations=5,
    batch_size=10_000,
    max_steps=100,
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
        println("Setting up solver for $(agent_type)...")

        # Get custom parameters for this agent type
        agent_networks = get(custom_networks, agent_type, Dict())
        value_net = get(agent_networks, :value_network, nothing)
        policy_net = get(agent_networks, :policy_network, nothing)
        custom_solver = get(custom_solvers, agent_type, nothing)
        solver_type = get(solver_types, agent_type, :PPO)
        solver_params_agent = Agents.process_solver_params(solver_params, agent_type)

        env, solver = Agents.setup_rl_training(
            model,
            agent_type;
            training_steps=batch_size,
            max_steps=max_steps,
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
                    model.trained_policies[other_type] = policy
                end
            end

            # Train the agent
            policy = solve(solvers[agent_type], envs[agent_type])
            policies[agent_type] = policy
        end
    end

    return policies, solvers
end

function Agents.create_value_network(input_dims, hidden_layers=[64, 64], activation=relu)
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

function Agents.create_policy_network(input_dims, output_dims, action_space, hidden_layers=[64, 64], activation=relu)
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

function Agents.create_custom_solver(solver_type, π, S; custom_params...)
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


function Agents.train_model!(model::ReinforcementLearningABM, training_mode::Symbol=:sequential;
    kwargs...)

    if isnothing(model.rl_config[])
        error("RL configuration not set. Use set_rl_config! first.")
    end

    config = model.rl_config[]
    if config.training_agent_types === nothing || isempty(config.training_agent_types)
        error("No training_agent_types specified in RL configuration.")
    end

    agent_types_vec = config.training_agent_types

    # Set training flag
    model.is_training[] = true

    try
        # Train agents based on mode
        if training_mode == :sequential
            policies, solvers = Agents.train_agent_sequential(model, agent_types_vec; kwargs...)
        elseif training_mode == :simultaneous
            policies, solvers = Agents.train_agent_simultaneous(model, agent_types_vec; kwargs...)
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

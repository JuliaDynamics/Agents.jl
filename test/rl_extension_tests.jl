using Agents
using POMDPs, Crux, Flux
using Test, StableRNGs

# Test agents for RL extension testing
@agent struct RLExtensionTestAgent(GridAgent{2})
    energy::Float64
    wealth::Float64
    last_action::Int = 0
end

@agent struct RLExtensionTestPredator(GridAgent{2})
    energy::Float64
    hunt_success::Int = 0
end

@agent struct RLExtensionTestPrey(GridAgent{2})
    energy::Float64
    escape_count::Int = 0
end

# Helper functions for RL extension testing
function create_simple_rl_model(; n_agents=5, dims=(8, 8), seed=42, observation_radius=2)
    rng = StableRNG(seed)
    space = GridSpace(dims; periodic=true)

    properties = Dict{Symbol,Any}(
        :observation_radius => observation_radius
    )

    model = ReinforcementLearningABM(RLExtensionTestAgent, space; rng=rng, properties=properties)

    for _ in 1:n_agents
        add_agent!(RLExtensionTestAgent, model, rand(rng) * 50.0, rand(rng) * 100.0, 0)
    end

    return model
end

function create_multi_agent_rl_model(; n_predators=3, n_prey=7, dims=(10, 10), seed=42, observation_radius=3)
    rng = StableRNG(seed)
    space = GridSpace(dims; periodic=true)

    properties = Dict{Symbol,Any}(
        :observation_radius => observation_radius
    )

    model = ReinforcementLearningABM(Union{RLExtensionTestPredator,RLExtensionTestPrey}, space; rng=rng, properties=properties)

    for _ in 1:n_predators
        add_agent!(RLExtensionTestPredator, model, rand(rng) * 30.0, 0)
    end

    for _ in 1:n_prey
        add_agent!(RLExtensionTestPrey, model, rand(rng) * 20.0, 0)
    end

    return model
end


function simple_observation_fn(agent, model)
    observation_radius = model.observation_radius
    # Simple observation: agent position, energy, wealth, and neighbor count
    neighbor_count = length([a for a in nearby_agents(agent, model, observation_radius)])
    return Float32[agent.pos[1], agent.pos[2], agent.energy/50.0, agent.wealth/100.0, neighbor_count/10.0]
end

function simple_reward_fn(agent, action, previous_model, current_model)
    # Death penalty
    if agent.id ∉ [a.id for a in allagents(current_model)]
        return -100.0f0
    end

    # Small positive reward for survival plus energy-based bonus
    reward = 1.0f0 + agent.energy / 100.0f0

    # Bonus for wealth increase
    if agent.id ∈ [a.id for a in allagents(previous_model)]
        initial_wealth = previous_model[agent.id].wealth
        if agent.wealth > initial_wealth
            reward += (agent.wealth - initial_wealth) / 10.0f0
        end
    end

    return Float32(reward)
end

function simple_terminal_fn(model)
    # Terminal if less than 2 agents remain or time exceeds limit
    return length(allagents(model)) < 2 || abmtime(model) >= 50
end

function simple_agent_step_fn(agent, model, action)
    agent.last_action = action

    # Actions: 1=stay, 2=north, 3=south, 4=east, 5=west
    current_x, current_y = agent.pos
    width, height = getfield(model, :space).extent

    dx, dy = 0, 0
    if action == 2      # North
        dy = 1
    elseif action == 3  # South
        dy = -1
    elseif action == 4  # East
        dx = 1
    elseif action == 5  # West
        dx = -1
    end

    # Apply periodic boundary movement
    if action != 1
        new_x = mod1(current_x + dx, width)
        new_y = mod1(current_y + dy, height)
        move_agent!(agent, (new_x, new_y), model)
    end

    # Energy and wealth updates
    agent.energy = max(0.0, agent.energy - 0.5)  # Movement cost
    if action == 1  # Stay action gives small wealth bonus
        agent.wealth += 1.0
        agent.energy += 0.5
    end

    # Remove agent if energy depleted
    if agent.energy <= 0
        remove_agent!(agent, model)
    end
end

function multi_agent_observation_fn(agent, model)
    observation_radius = model.observation_radius

    # Different observations for different agent types
    if agent isa RLExtensionTestPredator
        # Predators see prey positions and energy
        prey_nearby = length([a for a in nearby_agents(agent, model, observation_radius)
                              if a isa RLExtensionTestPrey])
        return Float32[agent.pos[1], agent.pos[2], agent.energy/30.0, Float32(prey_nearby)]
    else  # Prey
        # Prey see predator positions and escape routes
        predators_nearby = length([a for a in nearby_agents(agent, model, observation_radius)
                                   if a isa RLExtensionTestPredator])
        return Float32[agent.pos[1], agent.pos[2], agent.energy/20.0, Float32(predators_nearby)]
    end
end

function multi_agent_reward_fn(agent, action, previous_model, current_model)
    # Death penalty
    if agent.id ∉ [a.id for a in allagents(current_model)]
        return -50.0f0
    end

    if agent isa RLExtensionTestPredator
        # Predator rewards: hunt success
        reward = 0.5f0  # Base survival
        if agent.id ∈ [a.id for a in allagents(previous_model)]
            if agent.hunt_success > previous_model[agent.id].hunt_success
                reward += 10.0f0  # Hunt success bonus
            end
        end
    else  # Prey
        # Prey rewards: survival and escape
        reward = 1.0f0  # Base survival
        if agent.id ∈ [a.id for a in allagents(previous_model)]
            if agent.escape_count > previous_model[agent.id].escape_count
                reward += 5.0f0  # Escape bonus
            end
        end
    end

    return reward
end

function multi_agent_agent_step_fn(agent, model, action)
    # Basic movement (same as simple_agent_step_fn)
    current_x, current_y = agent.pos
    width, height = getfield(model, :space).extent

    dx, dy = 0, 0
    if action == 2      # North
        dy = 1
    elseif action == 3  # South
        dy = -1
    elseif action == 4  # East
        dx = 1
    elseif action == 5  # West
        dx = -1
    end

    if action != 1
        new_x = mod1(current_x + dx, width)
        new_y = mod1(current_y + dy, height)
        move_agent!(agent, (new_x, new_y), model)
    end

    # Type-specific behavior
    if agent isa RLExtensionTestPredator
        agent.energy = max(0.0, agent.energy - 1.0)  # Higher energy cost

        # Check for prey to hunt
        prey_here = [a for a in agents_in_position(agent.pos, model)
                     if a isa RLExtensionTestPrey]
        if !isempty(prey_here)
            prey = prey_here[1]
            remove_agent!(prey, model)
            agent.energy += 15.0  # Energy gain from hunt
            agent.hunt_success += 1
        end
    else  # Prey
        agent.energy = max(0.0, agent.energy - 0.5)  # Lower energy cost

        # Check if escaping from predator
        predators_nearby = [a for a in nearby_agents(agent, model, 1)
                            if a isa RLExtensionTestPredator]
        if !isempty(predators_nearby) && action != 1  # Moving away counts as escape attempt
            agent.escape_count += 1
        end

        # Energy recovery when staying
        if action == 1
            agent.energy += 1.0
        end
    end

    # Remove agent if energy depleted
    if agent.energy <= 0
        remove_agent!(agent, model)
    end
end

@testset "RL Extension Training Functions" begin

    @testset "Setup RL Training" begin
        model = create_simple_rl_model()

        # Set up RL configuration
        rl_config = RLConfig(;
            model_init_fn = () -> create_simple_rl_model(),
            observation_fn = simple_observation_fn,
            reward_fn = simple_reward_fn,
            terminal_fn = simple_terminal_fn,
            agent_step_fn = simple_agent_step_fn,
            action_spaces = Dict(
                RLExtensionTestAgent => Crux.DiscreteSpace(5)
            ),
            observation_spaces = Dict(
                RLExtensionTestAgent => Crux.ContinuousSpace((5,), Float32)
            ),
            training_agent_types = [RLExtensionTestAgent]
        )

        set_rl_config!(model, rl_config)

        # Test setup_rl_training function from extension
        env, solver = Agents.setup_rl_training(model, RLExtensionTestAgent; training_steps=1000)

        @test env isa POMDPs.POMDP
        @test solver isa OnPolicySolver

        # Test that solver has correct configuration
        @test solver.N == 1000  # Training steps
        @test solver.ΔN == 200  # Default batch size
        @test solver.agent isa PolicyParams
    end

    @testset "Custom Network Creation" begin
        model = create_simple_rl_model()

        rl_config = RLConfig(;
            model_init_fn = () -> create_simple_rl_model(),
            observation_fn = simple_observation_fn,
            reward_fn = simple_reward_fn,
            terminal_fn = simple_terminal_fn,
            agent_step_fn = simple_agent_step_fn,
            action_spaces = Dict(
                RLExtensionTestAgent => Crux.DiscreteSpace(5)
            ),
            observation_spaces = Dict(
                RLExtensionTestAgent => Crux.ContinuousSpace((5,), Float32)
            ),
            training_agent_types = [RLExtensionTestAgent]
        )

        set_rl_config!(model, rl_config)

        # Test custom network creation functions
        value_net_fn = Agents.create_value_network((5,), [32, 16])
        policy_net_fn = Agents.create_policy_network((5,), 5, Crux.DiscreteSpace(5).vals, [32, 16])

        @test value_net_fn isa Function
        @test policy_net_fn isa Function

        # Create networks and test structure
        value_net = value_net_fn()
        policy_net = policy_net_fn()

        @test value_net isa ContinuousNetwork
        @test policy_net isa DiscreteNetwork

        # Test with custom networks
        env, solver = Agents.setup_rl_training(model, RLExtensionTestAgent;
            training_steps=500,
            value_network=value_net_fn,
            policy_network=policy_net_fn
        )

        @test solver.agent.π.A isa DiscreteNetwork
        @test solver.agent.π.C isa ContinuousNetwork
    end

    @testset "Sequential Training" begin
        model = create_multi_agent_rl_model()

        # Set up multi-agent RL configuration
        rl_config = RLConfig(;
            model_init_fn = () -> create_multi_agent_rl_model(),
            observation_fn = multi_agent_observation_fn,
            reward_fn = multi_agent_reward_fn,
            terminal_fn = (model) -> length(allagents(model)) < 3 || abmtime(model) >= 30,
            agent_step_fn = multi_agent_agent_step_fn,
            action_spaces = Dict(
                RLExtensionTestPredator => Crux.DiscreteSpace(5),
                RLExtensionTestPrey => Crux.DiscreteSpace(5)
            ),
            observation_spaces = Dict(
                RLExtensionTestPredator => Crux.ContinuousSpace((4,), Float32),
                RLExtensionTestPrey => Crux.ContinuousSpace((4,), Float32)
            ),
            training_agent_types = [RLExtensionTestPredator, RLExtensionTestPrey]
        )

        set_rl_config!(model, rl_config)

        # Test sequential training with small parameters for speed
        policies, solvers = Agents.train_agent_sequential(model,
            [RLExtensionTestPredator, RLExtensionTestPrey];
            training_steps=10,
            solver_params=Dict(:ΔN => 5)
        )

        @test length(policies) == 2
        @test length(solvers) == 2
        @test haskey(policies, RLExtensionTestPredator)
        @test haskey(policies, RLExtensionTestPrey)
        @test haskey(solvers, RLExtensionTestPredator)
        @test haskey(solvers, RLExtensionTestPrey)

        # Test that policies are different objects
        @test policies[RLExtensionTestPredator] !== policies[RLExtensionTestPrey]
        @test solvers[RLExtensionTestPredator] !== solvers[RLExtensionTestPrey]

        # Test that trained policies are stored in model
        stored_policies = get_trained_policies(model)
        @test haskey(stored_policies, RLExtensionTestPredator)
    end

    @testset "Simultaneous Training" begin
        model = create_multi_agent_rl_model(n_predators=2, n_prey=3)

        rl_config = RLConfig(;
            model_init_fn = () -> create_multi_agent_rl_model(n_predators=2, n_prey=3),
            observation_fn = multi_agent_observation_fn,
            reward_fn = multi_agent_reward_fn,
            terminal_fn = (model) -> length(allagents(model)) < 2 || abmtime(model) >= 25,
            agent_step_fn = multi_agent_agent_step_fn,
            action_spaces = Dict(
                RLExtensionTestPredator => Crux.DiscreteSpace(5),
                RLExtensionTestPrey => Crux.DiscreteSpace(5)
            ),
            observation_spaces = Dict(
                RLExtensionTestPredator => Crux.ContinuousSpace((4,), Float32),
                RLExtensionTestPrey => Crux.ContinuousSpace((4,), Float32)
            ),
            training_agent_types = [RLExtensionTestPredator, RLExtensionTestPrey]
        )

        set_rl_config!(model, rl_config)

        # Test simultaneous training with small parameters
        policies, solvers = Agents.train_agent_simultaneous(model,
            [RLExtensionTestPredator, RLExtensionTestPrey];
            n_iterations=2,
            batch_size=10,
            solver_params=Dict(:ΔN => 5)
        )

        @test length(policies) == 2
        @test length(solvers) == 2
        @test haskey(policies, RLExtensionTestPredator)
        @test haskey(policies, RLExtensionTestPrey)

        # Verify policies are different
        @test policies[RLExtensionTestPredator] !== policies[RLExtensionTestPrey]

        # Test that model has been updated with trained policies
        stored_policies = get_trained_policies(model)
        @test haskey(stored_policies, RLExtensionTestPredator)
        @test haskey(stored_policies, RLExtensionTestPrey)
    end

    @testset "Train Model Function Integration" begin
        model = create_simple_rl_model(n_agents=3)

        rl_config = RLConfig(;
            model_init_fn = () -> create_simple_rl_model(n_agents=3),
            observation_fn = simple_observation_fn,
            reward_fn = simple_reward_fn,
            terminal_fn = simple_terminal_fn,
            agent_step_fn = simple_agent_step_fn,
            action_spaces = Dict(
                RLExtensionTestAgent => Crux.DiscreteSpace(5)
            ),
            observation_spaces = Dict(
                RLExtensionTestAgent => Crux.ContinuousSpace((5,), Float32)
            ),
            training_agent_types = [RLExtensionTestAgent]
        )

        set_rl_config!(model, rl_config)

        # Test single agent training via train_model!
        train_model!(model;
            training_steps=10,
            solver_params=Dict(:ΔN => 5)
        )

        policies = get_trained_policies(model)
        @test haskey(policies, RLExtensionTestAgent)
        @test policies[RLExtensionTestAgent] isa Crux.ActorCritic

        # Test with different solver types
        model2 = create_simple_rl_model(n_agents=3)
        set_rl_config!(model2, rl_config)

        train_model!(model2;
            solver_types=Dict(RLExtensionTestAgent => :A2C),
            training_steps=10,
            solver_params=Dict(:ΔN => 5)
        )

        policies2 = get_trained_policies(model2)
        @test haskey(policies2, RLExtensionTestAgent)
        @test policies2[RLExtensionTestAgent] isa Crux.ActorCritic
    end

    @testset "Solver Parameter Processing" begin
        # Test process_solver_params function
        global_params = Dict(:ΔN => 100, :log => (period=500,))

        # Test with single agent type
        processed = Agents.process_solver_params(global_params, RLExtensionTestAgent)
        @test processed[:ΔN] == 100
        @test processed[:log] == (period=500,)

        # Test with agent-specific parameters
        agent_specific_params = Dict(
            RLExtensionTestPredator => Dict(:ΔN => 50, :lr => 0.001),
            RLExtensionTestPrey => Dict(:ΔN => 75, :lr => 0.002),
        )

        pred_params = Agents.process_solver_params(agent_specific_params, RLExtensionTestPredator)
        @test pred_params[:ΔN] == 50
        @test pred_params[:lr] == 0.001

        prey_params = Agents.process_solver_params(agent_specific_params, RLExtensionTestPrey)
        @test prey_params[:ΔN] == 75
        @test prey_params[:lr] == 0.002
    end

    @testset "Policy Copying and Management" begin
        # Create source model with training
        source_model = create_simple_rl_model()

        rl_config = RLConfig(;
            model_init_fn = () -> create_simple_rl_model(),
            observation_fn = simple_observation_fn,
            reward_fn = simple_reward_fn,
            terminal_fn = simple_terminal_fn,
            agent_step_fn = simple_agent_step_fn,
            action_spaces = Dict(
                RLExtensionTestAgent => Crux.DiscreteSpace(5)
            ),
            observation_spaces = Dict(
                RLExtensionTestAgent => Crux.ContinuousSpace((5,), Float32)
            ),
            training_agent_types = [RLExtensionTestAgent]
        )

        set_rl_config!(source_model, rl_config)

        # Train source model
        train_model!(source_model; training_steps=10,
            solver_params=Dict(:ΔN => 5))

        # Create target model and copy policies
        target_model = create_simple_rl_model()
        set_rl_config!(target_model, rl_config)

        @test isempty(get_trained_policies(target_model))

        copy_trained_policies!(target_model, source_model)

        target_policies = get_trained_policies(target_model)
        source_policies = get_trained_policies(source_model)
        @test haskey(target_policies, RLExtensionTestAgent)
        @test target_policies[RLExtensionTestAgent] === source_policies[RLExtensionTestAgent]
    end


    @testset "Different Solver Types" begin
        model = create_simple_rl_model()

        rl_config = RLConfig(;
            model_init_fn = () -> create_simple_rl_model(),
            observation_fn = simple_observation_fn,
            reward_fn = simple_reward_fn,
            terminal_fn = simple_terminal_fn,
            agent_step_fn = simple_agent_step_fn,
            action_spaces = Dict(
                RLExtensionTestAgent => Crux.DiscreteSpace(5)
            ),
            observation_spaces = Dict(
                RLExtensionTestAgent => Crux.ContinuousSpace((5,), Float32)
            ),
            training_agent_types = [RLExtensionTestAgent]
        )

        set_rl_config!(model, rl_config)

        # Test DQN solver
        env, solver = Agents.setup_rl_training(model, RLExtensionTestAgent;
            solver_type=:DQN, training_steps=100)
        @test solver isa OffPolicySolver

        # Test A2C solver
        env, solver = Agents.setup_rl_training(model, RLExtensionTestAgent;
            solver_type=:A2C, training_steps=100)
        @test solver isa OnPolicySolver

        # Test PPO solver (default)
        env, solver = Agents.setup_rl_training(model, RLExtensionTestAgent;
            solver_type=:PPO, training_steps=100)
        @test solver isa OnPolicySolver
    end
end
using Agents
using POMDPs, Crux, Flux
using Test, StableRNGs

# Test agents for RL testing
@agent struct RLTestAgent(GridAgent{2})
    wealth::Float64
    last_action::Int = 0
end

@agent struct RLTestAgent2(GridAgent{2})
    energy::Float64
    strategy::Int = 1
end

# Helper functions for testing
function test_observation_fn(agent_id::Int, model::ReinforcementLearningABM)
end

function test_reward_fn(env::ReinforcementLearningABM, agent::AbstractAgent, action::Int,
    initial_model::ReinforcementLearningABM, final_model::ReinforcementLearningABM)
end

function test_terminal_fn(env::ReinforcementLearningABM)
end

function test_agent_step_fn(agent::AbstractAgent, model::ReinforcementLearningABM, action::Int)
end

function test_model_init_fn()
    space = GridSpace((5, 5))
    model = ReinforcementLearningABM(RLTestAgent, space; rng=StableRNG(42))

    # Add some agents
    for _ in 1:3
        add_agent!(RLTestAgent, model, rand() * 50.0, 0)
    end

    return model
end

# Create basic RL configuration
function create_test_rl_config()
    return RLConfig(
        observation_fn=test_observation_fn,
        reward_fn=test_reward_fn,
        terminal_fn=test_terminal_fn,
        agent_step_fn=test_agent_step_fn,
        action_spaces=Dict(RLTestAgent => (; vals=1:5)),
        observation_spaces=Dict(RLTestAgent => (; dim=(3,))),
        training_agent_types=[RLTestAgent],
        discount_rates=Dict(RLTestAgent => 0.95),
        model_init_fn=test_model_init_fn
    )
end

@testset "ReinforcementLearningABM Interface Tests" begin

    @testset "Model Construction" begin
        space = GridSpace((5, 5))

        # Test basic construction
        model = ReinforcementLearningABM(RLTestAgent, space)
        @test model isa ReinforcementLearningABM
        @test abmspace(model) isa GridSpace
        @test isnothing(model.rl_config[])
        @test isempty(model.trained_policies)
        @test isempty(model.training_history)
        @test model.is_training[] == false
        @test isnothing(model.current_training_agent_type[])
        @test model.current_training_agent_id[] == 1

        # Test with initial RL config
        config = create_test_rl_config()
        model2 = ReinforcementLearningABM(RLTestAgent, space, config)
        @test !isnothing(model2.rl_config[])
        @test model2.rl_config[] isa RLConfig

        # Test with other standard parameters
        model3 = ReinforcementLearningABM(RLTestAgent, space;
            scheduler=Schedulers.ByID(),
            properties=Dict(:test => true),
            rng=StableRNG(123))
        @test model3.scheduler isa Schedulers.ByID
        @test model3.properties[:test] == true
        @test model3.rng isa StableRNG
    end

    @testset "RL Configuration Management" begin
        space = GridSpace((5, 5))
        model = ReinforcementLearningABM(RLTestAgent, space)

        # Test setting RL config
        config = create_test_rl_config()
        set_rl_config!(model, config)

        @test !isnothing(model.rl_config[])
        @test model.rl_config[] isa RLConfig
        @test haskey(model.rl_config[].action_spaces, RLTestAgent)
        @test model.rl_config[].training_agent_types == [RLTestAgent]

        # Test training history initialization
        @test haskey(model.training_history, RLTestAgent)
        @test isnothing(model.training_history[RLTestAgent])

        agent = add_agent!(RLTestAgent, model, 10.0, 0)

        @test model.rl_config[] isa RLConfig
        @test model.trained_policies isa Dict
        @test Agents.get_current_training_agent_type(model) == RLTestAgent
        @test Agents.get_current_training_agent(model) == agent

    end

    @testset "Property Access" begin
        space = GridSpace((5, 5))
        props = Dict(:custom_prop => 42, :another_prop => "test")
        model = ReinforcementLearningABM(RLTestAgent, space; properties=props)
        config = create_test_rl_config()
        set_rl_config!(model, config)

        # Test direct RL property access
        @test !isnothing(model.rl_config)
        @test isempty(model.trained_policies)
        @test !isempty(model.training_history)
        @test model.is_training[] == false

        # Test standard ABM property access
        @test model.agents isa AbstractDict
        @test model.space isa GridSpace
        @test model.maxid[] == 0
        @test model.time[] == 0

        # Test custom property access via properties
        @test model.custom_prop == 42
        @test model.another_prop == "test"

        # Test property modification
        model.custom_prop = 100
        @test model.custom_prop == 100
        @test model.properties[:custom_prop] == 100

        # Test error on setting properties field directly
        @test_throws ErrorException model.properties = Dict()
    end

    @testset "Agent Management" begin
        space = GridSpace((5, 5))
        model = ReinforcementLearningABM(RLTestAgent, space; rng=StableRNG(42))
        config = create_test_rl_config()
        set_rl_config!(model, config)

        # Add agents
        agent1 = add_agent!(RLTestAgent, model, 25.0, 0)
        agent2 = add_agent!(RLTestAgent, model, 30.0, 0)

        @test nagents(model) == 2
        @test model[agent1.id] isa RLTestAgent
        @test model[agent2.id] isa RLTestAgent

        # Test agent removal
        remove_agent!(agent1, model)
        @test nagents(model) == 1
        @test_throws KeyError model[agent1.id]
    end

    @testset "Current Training Agent Management" begin
        space = GridSpace((5, 5))
        model = ReinforcementLearningABM(RLTestAgent, space; rng=StableRNG(42))
        config = create_test_rl_config()
        set_rl_config!(model, config)

        # Test before adding agents
        @test Agents.get_current_training_agent_type(model) == RLTestAgent
        @test isnothing(Agents.get_current_training_agent(model))

        # Add agents and test cycling
        agent1 = add_agent!(RLTestAgent, model, 25.0, 0)
        agent2 = add_agent!(RLTestAgent, model, 30.0, 0)

        # Test first agent
        current_agent = Agents.get_current_training_agent(model)
        @test model.current_training_agent_id[] == 1

        model.current_training_agent_id[] += 1
        @test model.current_training_agent_id[] == 2
    end

    @testset "Model Reset" begin
        space = GridSpace((5, 5))
        model = ReinforcementLearningABM(RLTestAgent, space; rng=StableRNG(42))
        config = create_test_rl_config()
        set_rl_config!(model, config)

        # Add agents and advance time
        add_agent!(RLTestAgent, model, 25.0, 0)
        add_agent!(RLTestAgent, model, 30.0, 0)
        model.time[] = 10
        model.current_training_agent_id[] = 2

        # Test reset
        Agents.reset_model_for_episode!(model)
        @test model.time[] == 0
        @test model.current_training_agent_id[] == 1

        # Since we have model_init_fn, agents should be reset too
        @test nagents(model) == 3  # model_init_fn creates 3 agents
    end

    @testset "Policy Management" begin
        space = GridSpace((5, 5))
        model1 = ReinforcementLearningABM(RLTestAgent, space)
        model2 = ReinforcementLearningABM(RLTestAgent, space)

        # Test empty policies initially
        @test isempty(Agents.get_trained_policies(model1))
        @test isempty(Agents.get_trained_policies(model2))

        # Mock a trained policy
        mock_policy = "mock_policy_object"
        model1.trained_policies[RLTestAgent] = mock_policy

        @test haskey(Agents.get_trained_policies(model1), RLTestAgent)
        @test Agents.get_trained_policies(model1)[RLTestAgent] == mock_policy

        # Test policy copying
        copy_trained_policies!(model2, model1)
        @test haskey(Agents.get_trained_policies(model2), RLTestAgent)
        @test Agents.get_trained_policies(model2)[RLTestAgent] == mock_policy
    end

    @testset "Multi-Agent Type Configuration" begin
        space = GridSpace((5, 5))
        model = ReinforcementLearningABM(Union{RLTestAgent,RLTestAgent2}, space; rng=StableRNG(42))

        # Create config for multiple agent types
        config = RLConfig(
            observation_fn=(agent_id, model) -> Float32[model[agent_id].pos...],
            reward_fn=(env, agent, action, init, final) -> 1.0f0,
            terminal_fn=(env) -> false,
            agent_step_fn=(agent, model, action) -> nothing,
            action_spaces=Dict(
                RLTestAgent => (; vals=1:5),
                RLTestAgent2 => (; vals=1:3)
            ),
            observation_spaces=Dict(
                RLTestAgent => (; dim=(2,)),
                RLTestAgent2 => (; dim=(2,))
            ),
            training_agent_types=[RLTestAgent, RLTestAgent2],
            discount_rates=Dict(
                RLTestAgent => 0.95,
                RLTestAgent2 => 0.99
            )
        )

        set_rl_config!(model, config)

        # Add different agent types
        agent1 = add_agent!(RLTestAgent, model, 25.0, 0)
        agent2 = add_agent!(RLTestAgent2, model, 50.0, 0)

        @test nagents(model) == 2
        @test typeof(model[agent1.id]) == RLTestAgent
        @test typeof(model[agent2.id]) == RLTestAgent2

        # Test configuration access for different types
        @test haskey(model.rl_config[].action_spaces, RLTestAgent)
        @test haskey(model.rl_config[].action_spaces, RLTestAgent2)
        @test length(model.rl_config[].action_spaces[RLTestAgent].vals) == 5
        @test length(model.rl_config[].action_spaces[RLTestAgent2].vals) == 3
    end

    @testset "Configuration Validation and Error Handling" begin
        space = GridSpace((5, 5))
        model = ReinforcementLearningABM(RLTestAgent, space)

        # 1. Test errors when no RL config is set
        @test_throws ErrorException Agents.get_current_training_agent_type(model)
        @test_throws ErrorException Agents.get_current_training_agent(model)
        @test_throws ErrorException Agents.reset_model_for_episode!(model)

        # 2. Test with a minimal valid config
        minimal_config = RLConfig(
            observation_fn=(agent_id, model) -> Float32[1.0, 2.0],
            reward_fn=(agent, action, prev, curr) -> 1.0f0,
            training_agent_types=[RLTestAgent]
        )
        set_rl_config!(model, minimal_config)

        @test Agents.get_current_training_agent_type(model) == RLTestAgent
        @test isnothing(Agents.get_current_training_agent(model)) # No agents added yet

        # Reset should work with a minimal config (no model_init_fn)
        model.time[] = 5
        Agents.reset_model_for_episode!(model)
        @test model.time[] == 0

        # 3. Test error with an invalid config (empty training agent types)
        invalid_config = RLConfig(
            observation_fn=(agent_id, model) -> Float32[1.0, 2.0],
            reward_fn=(agent, action, prev, curr) -> 1.0f0,
            training_agent_types=[]
        )
        set_rl_config!(model, invalid_config)
        @test_throws ErrorException Agents.get_current_training_agent_type(model)
    end

    @testset "Standard ABM Interface Compatibility" begin
        space = GridSpace((5, 5))
        model = ReinforcementLearningABM(RLTestAgent, space; rng=StableRNG(42))
        config = create_test_rl_config()
        set_rl_config!(model, config)

        # Test that standard ABM functions work
        agent1 = add_agent!(RLTestAgent, model, 25.0, 0)
        agent2 = add_agent!(RLTestAgent, model, 50.0, 0)

        @test nagents(model) == 2
        @test abmtime(model) == 0
        @test abmspace(model) isa GridSpace
        @test abmscheduler(model) isa Schedulers.Randomly
        @test abmrng(model) isa StableRNG

        # Test agent access
        @test model[agent1.id] == agent1
        @test agent1 in allagents(model)

        # Test spatial queries
        neighbors = collect(nearby_agents(agent1, model, 5))
        @test agent2 in [n for n in neighbors]

        # Test scheduling
        scheduled_ids = collect(abmscheduler(model)(model))
        @test length(scheduled_ids) == 2
        @test agent1.id in scheduled_ids
        @test agent2.id in scheduled_ids
    end
end

# Test for RL wrapper functionality
@testset "RL Wrapper Interface Tests" begin

    # Define test components first
    @agent struct WrapperTestAgent(GridAgent{2})
        wealth::Float64
        last_action::Int = 0
    end

    function wrapper_test_observation_fn(agent_id::Int, model::ReinforcementLearningABM)
        agent = model[agent_id]
        # Return position and wealth as observation
        return Float32[agent.pos[1], agent.pos[2], agent.wealth/100.0]
    end

    function wrapper_test_reward_fn(env::ReinforcementLearningABM, agent::AbstractAgent, action::Int,
        initial_model::ReinforcementLearningABM, final_model::ReinforcementLearningABM)
        # Reward based on wealth increase
        initial_wealth = initial_model[agent.id].wealth
        final_wealth = agent.wealth
        return Float32(final_wealth - initial_wealth)
    end

    function wrapper_test_terminal_fn(env::ReinforcementLearningABM)
        # Terminal if any agent has wealth > 50 or time > 10
        return any(a.wealth > 50.0 for a in allagents(env)) || abmtime(env) >= 10
    end

    function wrapper_test_agent_step_fn(agent::AbstractAgent, model::ReinforcementLearningABM, action::Int)
        agent.last_action = action

        # Actions: 1=up, 2=right, 3=down, 4=left, 5=work(+wealth)
        if action == 1 && agent.pos[2] > 1
            move_agent!(agent, (agent.pos[1], agent.pos[2] - 1), model)
        elseif action == 2 && agent.pos[1] < abmspace(model).extent[1]
            move_agent!(agent, (agent.pos[1] + 1, agent.pos[2]), model)
        elseif action == 3 && agent.pos[2] < abmspace(model).extent[2]
            move_agent!(agent, (agent.pos[1], agent.pos[2] + 1), model)
        elseif action == 4 && agent.pos[1] > 1
            move_agent!(agent, (agent.pos[1] - 1, agent.pos[2]), model)
        elseif action == 5
            agent.wealth += 5.0
        end
    end

    function wrapper_test_model_init_fn()
        space = GridSpace((4, 4))
        model = ReinforcementLearningABM(WrapperTestAgent, space; rng=StableRNG(123))
        add_agent!(WrapperTestAgent, model, 10.0, 0)
        return model
    end

    function create_wrapper_test_config()
        return RLConfig(
            observation_fn=wrapper_test_observation_fn,
            reward_fn=wrapper_test_reward_fn,
            terminal_fn=wrapper_test_terminal_fn,
            agent_step_fn=wrapper_test_agent_step_fn,
            action_spaces=Dict(WrapperTestAgent => (; vals=1:5)),
            observation_spaces=Dict(WrapperTestAgent => (; dim=(3,))),
            training_agent_types=[WrapperTestAgent],
            discount_rates=Dict(WrapperTestAgent => 0.9),
            model_init_fn=wrapper_test_model_init_fn
        )
    end

    @testset "Wrapper Prerequisites" begin
        space = GridSpace((4, 4))
        model = ReinforcementLearningABM(WrapperTestAgent, space; rng=StableRNG(42))
        config = create_wrapper_test_config()
        set_rl_config!(model, config)

        # Add test agent
        agent = add_agent!(WrapperTestAgent, model, 15.0, 0)

        # Test observation function works
        obs = config.observation_fn(agent.id, model)
        @test obs isa Vector{Float32}
        @test length(obs) == 3
        @test obs[1] == 2.0f0  # x position
        @test obs[2] == 1.0f0  # y position
        @test obs[3] ≈ 0.15f0  # wealth/100

        # Test reward function works
        initial_model = deepcopy(model)
        wrapper_test_agent_step_fn(agent, model, 5)  # work action
        reward = config.reward_fn(model, agent, 5, initial_model, model)
        @test reward == 5.0f0  # wealth increased by 5

        # Test terminal function works
        @test config.terminal_fn(model) == false  # Not terminal yet

        agent.wealth = 60.0
        @test config.terminal_fn(model) == true  # Now terminal due to high wealth

        # Reset wealth and test time terminal
        agent.wealth = 20.0
        model.time[] = 15
        @test config.terminal_fn(model) == true  # Terminal due to time

        # Test agent step function works
        model.time[] = 0
        initial_pos = agent.pos
        wrapper_test_agent_step_fn(agent, model, 2)  # move right
        @test agent.pos == (initial_pos[1] + 1, initial_pos[2])
        @test agent.last_action == 2
    end

    @testset "Model Reset for Training Episodes" begin
        space = GridSpace((4, 4))
        model = ReinforcementLearningABM(WrapperTestAgent, space; rng=StableRNG(42))
        config = create_wrapper_test_config()
        set_rl_config!(model, config)

        # Add agents and modify state
        agent1 = add_agent!(WrapperTestAgent, model, 20.0, 0)
        agent2 = add_agent!(WrapperTestAgent, model, 25.0, 0)
        model.time[] = 5
        model.current_training_agent_id[] = 2

        @test nagents(model) == 2
        @test abmtime(model) == 5
        @test model.current_training_agent_id[] == 2

        # Reset using model_init_fn
        Agents.reset_model_for_episode!(model)

        @test abmtime(model) == 0
        @test model.current_training_agent_id[] == 1
        @test nagents(model) == 1  # model_init_fn creates only 1 agent

        # Verify the new agent has expected properties
        new_agent = collect(allagents(model))[1]
        @test new_agent.pos == (1, 4)
        @test new_agent.wealth == 10.0
    end

    @testset "Training Configuration Validation" begin
        space = GridSpace((3, 3))
        model = ReinforcementLearningABM(WrapperTestAgent, space)

        # Test that wrapper functions expect proper RL config structure
        config = create_wrapper_test_config()

        # Verify all required config components are present
        @test config isa RLConfig
        @test !isnothing(config.observation_fn)
        @test !isnothing(config.reward_fn)
        @test !isnothing(config.terminal_fn)
        @test !isnothing(config.agent_step_fn)
        @test !isnothing(config.action_spaces)
        @test !isnothing(config.observation_spaces)
        @test !isnothing(config.training_agent_types)
        @test !isnothing(config.discount_rates)

        # Test setting the config
        set_rl_config!(model, config)
        @test model.rl_config[] isa RLConfig
        @test model.rl_config[].observation_fn === config.observation_fn
        @test model.rl_config[].reward_fn === config.reward_fn

        # Verify action space structure
        action_space = config.action_spaces[WrapperTestAgent]
        @test haskey(action_space, :vals)
        @test action_space.vals == 1:5

        # Verify observation space structure
        obs_space = config.observation_spaces[WrapperTestAgent]
        @test haskey(obs_space, :dim)
        @test obs_space.dim == (3,)
    end

    @testset "Multi-Step Episode Simulation" begin
        space = GridSpace((4, 4))
        model = ReinforcementLearningABM(WrapperTestAgent, space; rng=StableRNG(42))
        config = create_wrapper_test_config()
        set_rl_config!(model, config)

        # Add an agent
        agent = add_agent!(WrapperTestAgent, model, 10.0, 0)

        # Simulate several actions that a wrapper would perform
        actions = [5, 2, 3, 5, 1]  # work, right, down, work, up

        for action in actions
            # Record initial state
            initial_model = deepcopy(model)
            initial_obs = config.observation_fn(agent.id, model)

            # Execute action
            config.agent_step_fn(agent, model, action)

            # Calculate reward
            reward = config.reward_fn(model, agent, action, initial_model, model)

            # Get new observation
            new_obs = config.observation_fn(agent.id, model)

            # Check terminal condition
            is_terminal = config.terminal_fn(model)

            # Verify reasonable behavior
            @test agent.last_action == action
            @test reward isa Float32
            @test new_obs isa Vector{Float32}
            @test length(new_obs) == 3

            if action == 5  # work action
                @test reward > 0.0  # Should get positive reward
            end

            if is_terminal
                break
            end

            # Advance time (simulating environment step)
            model.time[] += 1
        end

        # Verify agent has accumulated wealth from work actions
        @test agent.wealth > 10.0  # Started with 10, should have increased
        @test agent.wealth == 20.0  # Two work actions = +10 wealth
    end
end
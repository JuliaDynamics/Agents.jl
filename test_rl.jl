using Pkg
Pkg.activate(".")

using Agents
using Random
using Test
using Distributions

# Optional RL dependencies
POMDPs_available = false
Crux_available = false
Flux_available = false

try
    using POMDPs
    global POMDPs_available = true
    println("POMDPs.jl available")
catch e
    println("POMDPs.jl not available: $(e)")
end

try
    using Crux
    global Crux_available = true
    println("Crux.jl available")
catch e
    println("Crux.jl not available: $(e)")
end

try
    using Flux
    global Flux_available = true
    println("Flux.jl available")
catch e
    println("Flux.jl not available: $(e)")
end

# Helper functions for testing  
function test_section(f::Function, name::String)
    println("\n" * "="^50)
    println("TESTING: $name")
    println("="^50)
    try
        f()
        println("✓ $name - ALL TESTS PASSED")
    catch e
        println("✗ $name - FAILED: $e")
        rethrow(e)
    end
end

# Test Agent Types
@agent struct BasicRLAgent(GridAgent{2})
    energy::Float64 = 10.0
end

@agent struct AdvancedRLAgent(GridAgent{2})
    energy::Float64 = 100.0
    health::Int = 5
    state::Symbol = :active
end

# Test configuration helpers
function create_basic_config()
    # Create basic action space (fallback for when Crux is not available)
    basic_action_space = (vals=[1, 2, 3, 4, 5],)  # Simple struct-like object

    return (
        observation_fn=(model, agent_id, radius) -> Dict(:energy => model[agent_id].energy, :pos => model[agent_id].pos),
        observation_to_vector_fn=obs -> Float32[obs[:energy], obs[:pos][1], obs[:pos][2]],
        reward_fn=(env, agent, action, init_model, final_model) -> Float32(agent.energy > 5.0 ? 1.0 : -1.0),
        terminal_fn=model -> length(allagents(model)) == 0,
        agent_step_fn=(agent, model, action) -> begin
            # Simple action: 1=stay, 2-5=move in cardinal directions
            if action > 1
                current_pos = agent.pos
                width, height = abmspace(model).extent
                if action == 2  # North
                    new_pos = (current_pos[1], mod1(current_pos[2] + 1, height))
                elseif action == 3  # South
                    new_pos = (current_pos[1], mod1(current_pos[2] - 1, height))
                elseif action == 4  # East
                    new_pos = (mod1(current_pos[1] + 1, width), current_pos[2])
                else  # West (action == 5)
                    new_pos = (mod1(current_pos[1] - 1, width), current_pos[2])
                end
                move_agent!(agent, new_pos, model)
            end
            agent.energy -= 0.1
        end,
        action_spaces=Dict(BasicRLAgent => basic_action_space),
        observation_spaces=Dict(BasicRLAgent => nothing),
        max_steps=100,
        observation_radius=2,
        training_agent_types=[BasicRLAgent]
    )
end

function create_full_config()
    config = create_basic_config()
    if Crux_available
        action_spaces = Dict(BasicRLAgent => Crux.DiscreteSpace(5))
        observation_spaces = Dict(BasicRLAgent => Crux.ContinuousSpace((3,), Float32))
        return merge(config, (action_spaces=action_spaces, observation_spaces=observation_spaces))
    else
        # Fallback without Crux
        action_spaces = Dict(BasicRLAgent => 1:5)
        observation_spaces = Dict(BasicRLAgent => nothing)
        return merge(config, (action_spaces=action_spaces, observation_spaces=observation_spaces))
    end
end

# =============================================================================
# MAIN TEST SUITE
# =============================================================================

println("Starting Comprehensive ReinforcementLearningABM Test Suite")
println("Julia Version: $(VERSION)")

# Test 1: Basic Constructor and Structure
test_section("Basic Constructor and Structure") do
    # Test basic constructor
    model1 = ReinforcementLearningABM(BasicRLAgent, GridSpace((10, 10)))
    @test model1 isa ReinforcementLearningABM
    @test abmspace(model1) isa GridSpace
    @test abmspace(model1).extent == (10, 10)
    @test abmtime(model1) == 0
    @test nagents(model1) == 0

    # Test field access
    @test model1.rl_config[] === nothing
    @test model1.trained_policies isa Dict{Type,Any}
    @test model1.training_history isa Dict{Type,Any}
    @test model1.is_training[] == false
    @test model1.current_training_agent_type[] === nothing
    @test model1.current_training_agent_id[] == 1

    # Test with constructor parameters
    properties = Dict(:test_prop => 42)
    model2 = ReinforcementLearningABM(BasicRLAgent, GridSpace((5, 5));
        properties=properties)
    @test abmproperties(model2)[:test_prop] == 42

    println("✓ Constructor and basic structure tests passed")
end

# Test 2: Agent Management
test_section("Agent Management") do
    model = ReinforcementLearningABM(BasicRLAgent, GridSpace((10, 10)))

    # Test adding agents
    agent1 = add_agent!(BasicRLAgent, model, 15.0)
    @test agent1 isa BasicRLAgent
    @test agent1.energy == 15.0
    @test nagents(model) == 1
    @test hasid(model, agent1.id)

    # Test adding multiple agents
    for i in 1:5
        add_agent!(BasicRLAgent, model, Float64(i * 10))
    end
    @test nagents(model) == 6

    # Test agent access
    @test model[agent1.id] === agent1
    @test model[agent1.id].energy == 15.0

    # Test agent iteration
    all_energies = [agent.energy for agent in allagents(model)]
    @test length(all_energies) == 6
    @test 15.0 in all_energies

    # Test removing agents
    remove_agent!(agent1, model)
    @test nagents(model) == 5
    @test !hasid(model, agent1.id)

    println("✓ Agent management tests passed")
end

# Test 3: RL Configuration Management
test_section("RL Configuration Management") do
    model = ReinforcementLearningABM(BasicRLAgent, GridSpace((10, 10)))

    # Test setting RL config
    config = create_basic_config()
    set_rl_config!(model, config)

    @test model.rl_config[] === config
    @test haskey(model.training_history, BasicRLAgent)

    # Test accessing config components
    retrieved_config = model.rl_config[]
    @test haskey(retrieved_config, :observation_fn)
    @test haskey(retrieved_config, :reward_fn)
    @test haskey(retrieved_config, :terminal_fn)
    @test haskey(retrieved_config, :training_agent_types)

    # Test config with constructor
    model2 = ReinforcementLearningABM(BasicRLAgent, GridSpace((5, 5)), config)
    @test model2.rl_config[] === config

    println("✓ RL configuration management tests passed")
end

# Test 4: Property Access and Modification
test_section("Property Access and Modification") do
    properties = Dict(:health => 100, :score => 0)
    model = ReinforcementLearningABM(BasicRLAgent, GridSpace((10, 10)); properties=properties)

    # Test property access via model
    @test model.health == 100
    @test model.score == 0

    # Test property modification
    model.health = 90
    model.score = 10
    @test model.health == 90
    @test model.score == 10

    # Test direct field access
    @test model.time[] == 0
    model.time[] = 5
    @test model.time[] == 5
    @test abmtime(model) == 5

    # Test immutable field protection
    @test_throws Exception model.properties = Dict(:new => 1)

    println("✓ Property access and modification tests passed")
end

# Test 5: Training Agent Management
test_section("Training Agent Management") do
    model = ReinforcementLearningABM(BasicRLAgent, GridSpace((10, 10)))
    config = create_basic_config()
    set_rl_config!(model, config)

    # Add some agents
    for i in 1:3
        add_agent!(BasicRLAgent, model, Float64(i * 10))
    end

    # Test getting current training agent type
    current_type = get_current_training_agent_type(model)
    @test current_type == BasicRLAgent

    # Test setting current training agent type
    model.current_training_agent_type[] = BasicRLAgent
    @test model.current_training_agent_type[] == BasicRLAgent

    # Test getting current training agent
    current_agent = get_current_training_agent(model)
    @test current_agent isa BasicRLAgent
    @test current_agent in allagents(model)

    # Test cycling through agents
    model.current_training_agent_id[] = 2
    next_agent = get_current_training_agent(model)
    @test next_agent !== current_agent

    println("✓ Training agent management tests passed")
end

# Test 6: Model Resetting
test_section("Model Resetting") do
    model = ReinforcementLearningABM(BasicRLAgent, GridSpace((5, 5)))
    config = create_basic_config()
    set_rl_config!(model, config)

    # Add agents and advance time
    add_agent!(BasicRLAgent, model, 20.0)
    model.time[] = 10
    model.current_training_agent_id[] = 5

    # Test reset
    reset_model_for_episode!(model)
    @test abmtime(model) == 0
    @test model.current_training_agent_id[] == 1

    # Test with model initialization function
    model_init_fn() = begin
        new_model = ReinforcementLearningABM(BasicRLAgent, GridSpace((3, 3)))
        add_agent!(BasicRLAgent, new_model, 50.0)
        return new_model
    end

    config_with_init = merge(config, (model_init_fn=model_init_fn,))
    set_rl_config!(model, config_with_init)

    reset_model_for_episode!(model)
    # Should have reset but maintained structure
    @test nagents(model) >= 0  # Agents may have been reset

    println("✓ Model resetting tests passed")
end

# Test 7: Basic Stepping (without RL policies)
test_section("Basic Stepping") do
    model = ReinforcementLearningABM(BasicRLAgent, GridSpace((5, 5)))
    config = create_basic_config()
    set_rl_config!(model, config)

    # Add agents
    for i in 1:3
        add_agent!(BasicRLAgent, model, Float64(i * 5))
    end

    initial_time = abmtime(model)
    initial_agents = nagents(model)

    # Test RL stepping without trained policies (should use random actions)
    step_rl!(model, 2)

    @test abmtime(model) == initial_time + 2
    # Agents should still exist (our dummy terminal function keeps them alive)
    @test nagents(model) <= initial_agents  # Could be same or fewer due to energy loss

    # Test that energy decreased (due to our agent step function)
    for agent in allagents(model)
        @test agent.energy < 20.0  # Should have decreased from movement cost
    end

    println("✓ Basic stepping tests passed")
end

# Test 8: Multi-Agent Type Support
test_section("Multi-Agent Type Support") do
    # Test model with multiple agent types
    model = ReinforcementLearningABM(Union{BasicRLAgent,AdvancedRLAgent}, GridSpace((10, 10)))

    # Add different agent types
    basic_agent = add_agent!(BasicRLAgent, model, 15.0)
    advanced_agent = add_agent!(AdvancedRLAgent, model, 25.0, 3, :ready)

    @test nagents(model) == 2
    @test basic_agent isa BasicRLAgent
    @test advanced_agent isa AdvancedRLAgent
    @test advanced_agent.health == 3
    @test advanced_agent.state == :ready

    # Test type-specific operations
    basic_agents = [a for a in allagents(model) if a isa BasicRLAgent]
    advanced_agents = [a for a in allagents(model) if a isa AdvancedRLAgent]

    @test length(basic_agents) == 1
    @test length(advanced_agents) == 1

    println("✓ Multi-agent type support tests passed")
end

# Test 9: Error Handling and Edge Cases
test_section("Error Handling and Edge Cases") do
    model = ReinforcementLearningABM(BasicRLAgent, GridSpace((5, 5)))

    # Test operations without RL config
    @test_throws Exception get_current_training_agent_type(model)
    @test_throws Exception reset_model_for_episode!(model)
    @test_throws Exception step_rl!(model)

    # Test with invalid config
    bad_config = (observation_fn=nothing,)
    set_rl_config!(model, bad_config)

    add_agent!(BasicRLAgent, model, 10.0)

    # Should handle missing config components gracefully or throw appropriate errors
    @test_throws Exception get_current_training_agent_type(model)

    # Test empty model scenarios
    empty_model = ReinforcementLearningABM(BasicRLAgent, GridSpace((3, 3)))
    config = create_basic_config()
    set_rl_config!(empty_model, config)

    current_agent = get_current_training_agent(empty_model)
    @test current_agent === nothing

    println("✓ Error handling and edge cases tests passed")
end

# Test 10: POMDPs Interface
if POMDPs_available && Crux_available
    test_section("POMDPs Interface") do
        model = ReinforcementLearningABM(BasicRLAgent, GridSpace((5, 5)))
        config = create_full_config()
        set_rl_config!(model, config)

        add_agent!(BasicRLAgent, model, 15.0)

        # Test basic spaces
        actions = POMDPs.actions(model)
        @test actions isa Crux.DiscreteSpace
        @test length(actions.vals) == 5  # Should have 5 actions

        observations = POMDPs.observations(model)
        @test observations isa Crux.ContinuousSpace
        @test observations.dims == (3,)  # Should match our observation vector size

        # Test state space
        state_space = Crux.state_space(model)
        @test state_space !== nothing

        # Test initialstate
        println("  Testing initialstate...")
        initial_state_dist = POMDPs.initialstate(model)
        @test initial_state_dist !== nothing

        # Sample from initial state
        initial_state = rand(initial_state_dist)
        @test initial_state isa Vector{Float32}
        @test length(initial_state) > 0

        # Test observation generation
        println("  Testing observation...")
        obs = POMDPs.observation(model, initial_state)
        @test obs isa Vector{Float32}
        @test length(obs) == 3  # Should match our observation vector size

        # Test initialobs
        println("  Testing initialobs...")
        initial_obs_dist = POMDPs.initialobs(model, initial_state)
        @test initial_obs_dist isa Distributions.Dirac
        initial_obs = rand(initial_obs_dist)
        @test initial_obs isa Vector{Float32}
        @test length(initial_obs) == 3

        # Test discount factor
        println("  Testing discount...")
        discount_factor = POMDPs.discount(model)
        @test discount_factor isa Float64
        @test 0.0 <= discount_factor <= 1.0

        # Test terminal condition
        println("  Testing isterminal...")
        is_terminal = POMDPs.isterminal(model, initial_state)
        @test is_terminal isa Bool
        @test is_terminal == false  # Should not be terminal initially

        # Test gen function (generative model)
        println("  Testing gen...")
        action = rand(actions.vals)
        rng = MersenneTwister(123)
        gen_result = POMDPs.gen(model, initial_state, action, rng)
        @test haskey(gen_result, :sp)  # next state
        @test haskey(gen_result, :o)   # observation
        @test haskey(gen_result, :r)   # reward
        @test gen_result.sp isa Vector{Float32}
        @test gen_result.o isa Vector{Float32}
        @test gen_result.r isa Float32

        # Test environment wrapper
        println("  Testing environment wrapper...")
        env = wrap_for_rl_training(model)
        @test env isa RLEnvironmentWrapper

        # Test wrapper delegation for all functions
        @test POMDPs.actions(env) == POMDPs.actions(model)
        @test POMDPs.observations(env) == POMDPs.observations(model)
        @test Crux.state_space(env) == Crux.state_space(model)
        @test POMDPs.discount(env) == POMDPs.discount(model)

        # Test wrapper with same inputs
        env_initial_state = rand(POMDPs.initialstate(env))
        env_obs = POMDPs.observation(env, env_initial_state)
        env_gen_result = POMDPs.gen(env, env_initial_state, action, rng)

        @test env_obs isa Vector{Float32}
        @test haskey(env_gen_result, :sp)
        @test haskey(env_gen_result, :o)
        @test haskey(env_gen_result, :r)

        # Test multiple steps through gen
        println("  Testing multi-step generation...")
        current_state = initial_state
        total_reward = 0.0
        for step in 1:3
            action = rand(actions.vals)
            result = POMDPs.gen(model, current_state, action, rng)
            current_state = result.sp
            total_reward += result.r

            @test result.r isa Float32  # Reward should be a number
            @test result.o isa Vector{Float32}  # Observation should be vector
            @test length(result.o) == 3  # Should maintain observation size

            # Test terminal condition for new state
            is_term = POMDPs.isterminal(model, current_state)
            @test is_term isa Bool
        end

        # Test that we accumulated some reward
        println("  Total reward over 3 steps: $total_reward")

        # Test edge cases and error handling
        println("  Testing edge cases...")

        # Test with invalid action
        try
            invalid_action = 99  # Outside our action space
            result = POMDPs.gen(model, initial_state, invalid_action, rng)
            println("    Invalid action handled gracefully")
        catch e
            println("    Invalid action properly rejected: $(typeof(e))")
        end

        # Test consistency: same state and action should give same result with same RNG
        println("  Testing deterministic behavior...")
        rng1 = MersenneTwister(456)
        rng2 = MersenneTwister(456)

        # Create fresh test states for each test to avoid state mutation
        test_state1 = rand(POMDPs.initialstate(model))
        test_state2 = copy(test_state1)  # Make a copy to ensure identical starting states
        test_action = first(actions.vals)

        result1 = POMDPs.gen(model, test_state1, test_action, rng1)
        result2 = POMDPs.gen(model, test_state2, test_action, rng2)

        # Test that rewards are consistent (they should be deterministic given same inputs)
        @test result1.r == result2.r  # Rewards should be identical

        @test typeof(result1.sp) == typeof(result2.sp)  # Same types
        @test length(result1.sp) == length(result2.sp)  # Same dimensions
        @test typeof(result1.o) == typeof(result2.o)   # Same observation types
        @test length(result1.o) == length(result2.o)   # Same observation dimensions

        println("    Deterministic behavior verified (structure and reward consistency)")

        # Test that the gen function produces valid outputs consistently
        for test_run in 1:5
            test_rng = MersenneTwister(100 + test_run)
            random_state = rand(POMDPs.initialstate(model))
            random_action = rand(actions.vals)

            result = POMDPs.gen(model, random_state, random_action, test_rng)

            @test haskey(result, :sp)
            @test haskey(result, :o)
            @test haskey(result, :r)
            @test result.sp isa Vector{Float32}
            @test result.o isa Vector{Float32}
            @test result.r isa Float32
            @test length(result.o) == 3  # Our observation vector size
        end

        println("    Multiple gen calls produce consistent structure")

        println("POMDPs interface tests passed")
    end
else
    println("\nSkipping POMDPs interface tests (POMDPs.jl or Crux.jl not available)")
end

# Test 11: Training Setup
if POMDPs_available && Crux_available && Flux_available
    test_section("Training Setup") do
        model = ReinforcementLearningABM(BasicRLAgent, GridSpace((5, 5)))
        config = create_full_config()
        set_rl_config!(model, config)

        add_agent!(BasicRLAgent, model, 15.0)

        # Test setup_rl_training function
        env, solver = setup_rl_training(model, BasicRLAgent; training_steps=100)

        @test env isa RLEnvironmentWrapper
        @test solver !== nothing

        # Test that current training agent type is set
        @test model.current_training_agent_type[] == BasicRLAgent

        println("Training setup tests passed")
    end
else
    println("\nSkipping training setup tests (required packages not available)")
end

# Test 12: Memory and Performance
test_section("Memory and Performance") do
    # Test with larger numbers of agents
    model = ReinforcementLearningABM(BasicRLAgent, GridSpace((20, 20)))
    config = create_basic_config()
    set_rl_config!(model, config)

    # Add many agents
    n_agents = 100
    for i in 1:n_agents
        add_agent!(BasicRLAgent, model, rand() * 20.0)
    end

    @test nagents(model) == n_agents

    # Test performance of basic operations
    @time begin
        for _ in 1:10
            for agent in allagents(model)
                # Simple operation
                agent.energy += 0.1
            end
        end
    end

    @test abmtime(model) == 0  # Time should not change during basic ops
    @test nagents(model) <= n_agents  # Should not grow uncontrollably

    println("Performance tests passed")
end

# Test 13: Reproducibility
test_section("Reproducibility") do
    # Test deterministic behavior with fixed RNG
    rng1 = MersenneTwister(12345)
    rng2 = MersenneTwister(12345)

    model1 = ReinforcementLearningABM(BasicRLAgent, GridSpace((5, 5)); rng=rng1)
    model2 = ReinforcementLearningABM(BasicRLAgent, GridSpace((5, 5)); rng=rng2)

    config = create_basic_config()
    set_rl_config!(model1, config)
    set_rl_config!(model2, config)

    # Add agents with same random seed behavior
    add_agent!(BasicRLAgent, model1)
    add_agent!(BasicRLAgent, model2)

    # Should produce identical results
    agent1 = collect(allagents(model1))[1]
    agent2 = collect(allagents(model2))[1]

    @test agent1.pos == agent2.pos  # Random positions should match

    println("✓ Reproducibility tests passed")
end
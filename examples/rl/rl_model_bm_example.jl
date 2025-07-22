using Agents, Random, Statistics, POMDPs, Crux, Flux, Distributions
include("../../src/core/rl_utils.jl")
include("../../src/core/rl_training_functions.jl")

## Example 2: Converting Boltzmann Model to use the General Interface
# Define Boltzmann agent for ReinforcementLearningABM
@agent struct RLBoltzmannAgent(GridAgent{2})
    wealth::Int
end

# Gini coefficient calculation
function gini(wealths::Vector{Int})
    n = length(wealths)
    if n <= 1
        return 0.0
    end
    sorted_wealths = sort(wealths)
    sum_wi = sum(sorted_wealths)
    if sum_wi == 0
        return 0.0
    end
    numerator = sum((2i - n - 1) * w for (i, w) in enumerate(sorted_wealths))
    denominator = n * sum_wi
    return numerator / denominator
end

# Define the agent stepping function for Boltzmann agents in RL model
function boltzmann_rl_step!(agent::RLBoltzmannAgent, model, action::Int)
    # Action definitions: 1=stay, 2=north, 3=south, 4=east, 5=west
    current_x, current_y = agent.pos
    width, height = getfield(model, :space).extent

    #println("DEBUG: Agent $(agent.id) starting step with wealth $(agent.wealth) at position $(agent.pos)")

    dx, dy = 0, 0
    if action == 2
        dy = 1
    elseif action == 3
        dy = -1
    elseif action == 4
        dx = 1
    elseif action == 5
        dx = -1
    end

    # Apply periodic boundary wrapping
    new_x = mod1(current_x + dx, width)
    new_y = mod1(current_y + dy, height)
    target_pos = (new_x, new_y)

    #println("DEBUG: Agent $(agent.id) moving from $(agent.pos) to $target_pos with action $action")

    move_agent!(agent, target_pos, model)

    #println("DEBUG: Agent $(agent.id) moved to $(agent.pos)")

    # Wealth exchange
    others = [a for a in agents_in_position(agent.pos, model) if a.id != agent.id]
    #println("DEBUG: Agent $(agent.id) found $(length(others)) other agents at position $(agent.pos)")

    if !isempty(others)
        other = rand(others)
        #println("DEBUG: Agent $(agent.id) (wealth=$(agent.wealth)) interacting with Agent $(other.id) (wealth=$(other.wealth))")

        if other.wealth > agent.wealth && other.wealth > 0
            # Transfer wealth from other to agent
            old_agent_wealth = agent.wealth
            old_other_wealth = other.wealth
            agent.wealth += 1
            other.wealth -= 1
            #println("DEBUG: Wealth transfer! Agent $(agent.id): $old_agent_wealth -> $(agent.wealth), Agent $(other.id): $old_other_wealth -> $(other.wealth)")
        else
            #println("DEBUG: No wealth transfer - condition not met")
        end
    else
        #println("DEBUG: No other agents at position $(agent.pos) for wealth exchange")
    end

    #println("DEBUG: Agent $(agent.id) finished step with wealth $(agent.wealth)")
end

# Boltzmann observation function
function get_local_observation_boltzmann(model::ABM, agent_id::Int, observation_radius::Int)
    target_agent = model[agent_id]
    agent_pos = target_agent.pos
    width, height = getfield(model, :space).extent

    grid_size = 2 * observation_radius + 1
    # 2 channels: occupancy and relative wealth
    neighborhood_grid = zeros(Float32, grid_size, grid_size, 2)

    # Get all agents in the neighborhood
    neighbor_ids = nearby_ids(target_agent, model, observation_radius)

    for neighbor in [model[id] for id in neighbor_ids]
        if neighbor.id == agent_id
            continue
        end

        # Calculate relative position with periodic boundaries
        dx = neighbor.pos[1] - agent_pos[1]
        dy = neighbor.pos[2] - agent_pos[2]
        # Wrap around for periodic space
        if abs(dx) > width / 2
            dx -= sign(dx) * width
        end
        if abs(dy) > height / 2
            dy -= sign(dy) * height
        end

        # Convert to grid coordinates (center is at radius + 1)
        grid_x = dx + observation_radius + 1
        grid_y = dy + observation_radius + 1

        if 1 <= grid_x <= grid_size && 1 <= grid_y <= grid_size
            # Channel 1: Occupancy
            neighborhood_grid[grid_x, grid_y, 1] = 1.0

            # Channel 2: Normalized Relative Wealth
            wealth_diff = Float32(neighbor.wealth - target_agent.wealth)
            wealth_sum = Float32(neighbor.wealth + target_agent.wealth)
            if wealth_sum > 0
                neighborhood_grid[grid_x, grid_y, 2] = wealth_diff / wealth_sum
            end
        end
    end

    # Normalize own agent's data
    total_wealth = sum(a.wealth for a in allagents(model))
    normalized_wealth = total_wealth > 0 ? Float32(target_agent.wealth / total_wealth) : 0.0f0
    normalized_pos = (Float32(agent_pos[1] / width), Float32(agent_pos[2] / height))

    return (
        agent_id=agent_id,
        normalized_wealth=normalized_wealth,
        normalized_pos=normalized_pos,
        neighborhood_grid=neighborhood_grid
    )
end

# Define observation function  
function boltzmann_get_observation(model, agent_id, observation_radius)
    return get_local_observation_boltzmann(model, agent_id, observation_radius)
end

# Convert boltzmann observation to vector
function observation_to_vector_boltzmann(obs)
    # Flatten the 3D neighborhood grid
    flattened_grid = vec(obs.neighborhood_grid)

    # Combine all normalized features into a single vector
    return vcat(
        Float32(obs.normalized_wealth),
        Float32(obs.normalized_pos[1]),
        Float32(obs.normalized_pos[2]),
        flattened_grid
    )
end

# Define reward function
function boltzmann_calculate_reward(env, agent, action, initial_model, final_model)
    # Calculate Gini coefficient change
    initial_wealths = [a.wealth for a in allagents(initial_model)]
    #println("DEBUG REWARD: Initial wealths: $initial_wealths")
    final_wealths = [a.wealth for a in allagents(final_model)]
    #println("DEBUG REWARD: Final wealths: $final_wealths")

    initial_gini = gini(initial_wealths)
    final_gini = gini(final_wealths)

    #println("DEBUG REWARD: Gini change: $initial_gini -> $final_gini")

    # Reward decrease in Gini coefficient
    reward = (initial_gini - final_gini) * 100
    if reward > 0
        reward = reward / (abmtime(env) + 1)
    end

    # Small penalty for neutral actions
    if reward <= 0.0
        reward = -0.1f0
    end

    #println("DEBUG REWARD: Calculated reward: $reward for agent $(agent.id)")
    return reward
end

# Define terminal condition for Boltzmann RL model
function boltzmann_is_terminal_rl(env)
    wealths = [a.wealth for a in allagents(env)]
    current_gini = gini(wealths)
    #println("DEBUG TERMINAL: Current Gini: $current_gini")
    return current_gini < 0.1  # Gini threshold
end

# Define a separate function for model initialization
function create_fresh_boltzmann_model(num_agents, dims, initial_wealth, seed)
    rng = MersenneTwister(seed)
    space = GridSpace(dims; periodic=true)

    properties = Dict{Symbol,Any}(
        :gini_coefficient => 0.0,
        :step_count => 0
    )

    model = ReinforcementLearningABM(RLBoltzmannAgent, space;
        properties=properties, rng=rng)

    # Add agents
    for _ in 1:num_agents
        add_agent_single!(RLBoltzmannAgent, model, rand(rng, 1:initial_wealth))
    end

    # Calculate initial Gini coefficient
    wealths = [a.wealth for a in allagents(model)]
    model.gini_coefficient = gini(wealths)

    return model
end

function initialize_boltzmann_rl_model(; num_agents=10, dims=(10, 10), initial_wealth=10, seed=1234)
    # RL configuration
    rl_config = (
        model_init_fn=() -> create_fresh_boltzmann_model(num_agents, dims, initial_wealth, seed),
        observation_fn=boltzmann_get_observation,
        observation_to_vector_fn=observation_to_vector_boltzmann,
        reward_fn=boltzmann_calculate_reward,
        terminal_fn=boltzmann_is_terminal_rl,
        agent_step_fn=boltzmann_rl_step!,
        action_spaces=Dict(
            RLBoltzmannAgent => Crux.DiscreteSpace(5)
        ),
        observation_spaces=Dict(
            RLBoltzmannAgent => Crux.ContinuousSpace((((2 * 4 + 1)^2 * 2) + 3,), Float32)
        ),
        training_agent_types=[RLBoltzmannAgent],
        max_steps=50,
        observation_radius=4
    )

    # Create the main model using the initialization function
    model = create_fresh_boltzmann_model(num_agents, dims, initial_wealth, seed)

    # Set the RL configuration
    set_rl_config!(model, rl_config)

    return model
end

# Create and train the Boltzmann RL model
boltzmann_rl_model = initialize_boltzmann_rl_model()

println("Created Boltzmann ReinforcementLearningABM with $(nagents(boltzmann_rl_model)) agents")
println("Initial Gini coefficient: $(boltzmann_rl_model.gini_coefficient)")

# Train the Boltzmann agents
println("\nTraining RLBoltzmannAgent...")
try
    train_model!(boltzmann_rl_model, RLBoltzmannAgent; training_steps=10000)
    println("DEBUG: Boltzmann RL training completed successfully")
catch e
    println("DEBUG: Boltzmann RL training failed with error: $e")
    println("DEBUG: Error type: $(typeof(e))")
    rethrow(e)
end


# Create a fresh model instance for simulation with the same parameters
println("\nCreating fresh Boltzmann model for simulation...")
fresh_boltzmann_model = create_fresh_boltzmann_model(10, (10, 10), 10, 1234)
set_rl_config!(fresh_boltzmann_model, boltzmann_rl_model.rl_config[])
println("DEBUG: Applied trained policies to fresh model")

# Run simulation with trained agents on the fresh model
println("\nRunning Boltzmann simulation with trained RL agents...")
initial_wealths = [a.wealth for a in allagents(fresh_boltzmann_model)]
initial_gini = gini(initial_wealths)
println("DEBUG: Initial wealths: $initial_wealths")
println("DEBUG: Initial Gini: $initial_gini")

try
    step_rl!(fresh_boltzmann_model, 15)
    println("DEBUG: Boltzmann step_rl! completed successfully")
catch e
    println("DEBUG: Boltzmann step_rl! failed with error: $e")
    println("DEBUG: Error type: $(typeof(e))")
    rethrow(e)
end

final_wealths = [a.wealth for a in allagents(fresh_boltzmann_model)]
final_gini = gini(final_wealths)

println("Gini coefficient: $initial_gini -> $final_gini")
println("Wealth distribution changed from $initial_wealths to $final_wealths")

println("\nBoltzmann ReinforcementLearningABM example completed!")

# Example usage of the General RL Interface with existing models
using Agents, Random, Statistics, POMDPs, Crux, Flux
include("../../src/core/rl_interface.jl")

## Example 2: Converting Boltzmann Model to use the General Interface
## Define Boltzmann Agent Type and Functions
@agent struct BoltzmannAgent(GridAgent{2})
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

# Boltzmann model initialization
function boltzmann_money_model_rl_init(; num_agents=100, dims=(10, 10), seed=1234, initial_wealth=1)
    space = GridSpace(dims; periodic=true)
    rng = MersenneTwister(seed)
    properties = Dict{Symbol,Any}(
        :gini_coefficient => 0.0,
        :step_count => 0
    )
    model = StandardABM(BoltzmannAgent, space; rng, properties=properties)

    for _ in 1:num_agents
        add_agent_single!(BoltzmannAgent, model, rand(rng, 1:initial_wealth))
    end
    wealths = [a.wealth for a in allagents(model)]
    model.gini_coefficient = gini(wealths)
    return model
end

# Boltzmann step function
function boltz_step!(agent::BoltzmannAgent, model::ABM, action::Int)
    # Action definitions: 1=stay, 2=north, 3=south, 4=east, 5=west
    current_x, current_y = agent.pos
    width, height = getfield(model, :space).extent

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

    move_agent!(agent, target_pos, model)

    # Wealth exchange
    others = [a for a in agents_in_position(agent.pos, model) if a.id != agent.id]
    if !isempty(others)
        other = rand(others)
        if other.wealth > agent.wealth && other.wealth > 0
            # Transfer wealth from other to agent
            agent.wealth += 1
            other.wealth -= 1
        end
    end
end

# Boltzmann observation function (reuse the same get_local_observation with different interpretation)
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

# Define the agent stepping function
function boltzmann_rl_step!(agent, model, action::Int)
    boltz_step!(agent, model, action)
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
    final_wealths = [a.wealth for a in allagents(final_model)]

    initial_gini = gini(initial_wealths)
    final_gini = gini(final_wealths)

    # Reward decrease in Gini coefficient
    reward = (initial_gini - final_gini) * 100
    if reward > 0
        reward = reward / (env.abm_model.step_count + 1)
    end

    # Small penalty for neutral actions
    if reward <= 0.0
        reward = -0.05
    end

    return reward
end

# Define terminal condition
function boltzmann_is_terminal(env)
    wealths = [a.wealth for a in allagents(env.abm_model)]
    current_gini = gini(wealths)
    return current_gini < 0.1  # Gini threshold
end

# Set up the environment configuration
boltzmann_obs_radius = 4
boltzmann_config = (
    model_init_fn=boltzmann_money_model_rl_init,
    agent_step_fn=boltzmann_rl_step!,
    observation_fn=boltzmann_get_observation,
    observation_to_vector_fn=observation_to_vector_boltzmann,
    reward_fn=boltzmann_calculate_reward,
    terminal_fn=boltzmann_is_terminal,
    training_agent_types=[BoltzmannAgent],
    action_spaces=Dict(
        BoltzmannAgent => Crux.DiscreteSpace(5)  # Stay, N, S, E, W
    ),
    observation_spaces=Dict(
        BoltzmannAgent => Crux.ContinuousSpace((((2 * boltzmann_obs_radius + 1)^2 * 2) + 3,), Float32)  # grid + own features
    ),
    max_steps=50,
    observation_radius=boltzmann_obs_radius,
    model_params=Dict(
        :num_agents => 10,
        :dims => (10, 10),
        :initial_wealth => 10
    )
)

# Train the agent
boltzmann_policy, boltzmann_solver = train_agent_sequential([BoltzmannAgent], boltzmann_config; training_steps=100_000)
plot_learning(boltzmann_solver[BoltzmannAgent])
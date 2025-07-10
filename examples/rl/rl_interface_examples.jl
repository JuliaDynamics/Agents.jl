# Example usage of the General RL Interface with existing models
using Agents, Random, Statistics, POMDPs, Crux, Flux
include("../../src/core/rl_interface.jl")

## Example 1: Converting Wolf-Sheep Model to use the General Interface
# Define Wolf-Sheep Agent Types and Functions
@agent struct Sheep(GridAgent{2})
    energy::Float64
    reproduction_prob::Float64
    Δenergy::Float64
end

@agent struct Wolf(GridAgent{2})
    energy::Float64
    reproduction_prob::Float64
    Δenergy::Float64
end

# Wolf-sheep model initialize
function initialize_model_rl(;
    n_sheep=100,
    n_wolves=10,
    dims=(20, 20),
    regrowth_time=30,
    Δenergy_sheep=5,
    Δenergy_wolf=30,
    sheep_reproduce=0.31,
    wolf_reproduce=0.06,
    seed=23182,
)
    rng = MersenneTwister(seed)
    space = GridSpace(dims, periodic=true)

    properties = (
        fully_grown=falses(dims),
        countdown=zeros(Int, dims),
        regrowth_time=regrowth_time,
    )

    model = StandardABM(Union{Sheep,Wolf}, space;
        properties, rng, scheduler=Schedulers.Randomly(), warn=false
    )

    # Add agents
    for _ in 1:n_sheep
        energy = rand(abmrng(model), 1:(Δenergy_sheep*2)) - 1
        add_agent!(Sheep, model, energy, sheep_reproduce, Δenergy_sheep)
    end
    for _ in 1:n_wolves
        energy = rand(abmrng(model), 1:(Δenergy_wolf*2)) - 1
        add_agent!(Wolf, model, energy, wolf_reproduce, Δenergy_wolf)
    end

    # Add grass with random initial growth
    for p in positions(model)
        fully_grown = rand(abmrng(model), Bool)
        countdown = fully_grown ? regrowth_time : rand(abmrng(model), 1:regrowth_time) - 1
        model.countdown[p...] = countdown
        model.fully_grown[p...] = fully_grown
    end

    return model
end

# Wolf-sheep RL step functions
function sheepwolf_step_rl!(sheep::Sheep, model, action::Int)
    # Action definitions: 1=stay, 2=north, 3=south, 4=east, 5=west
    current_x, current_y = sheep.pos
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

    # Apply periodic boundary wrapping and move
    if action != 1  # If not staying
        new_x = mod1(current_x + dx, width)
        new_y = mod1(current_y + dy, height)
        move_agent!(sheep, (new_x, new_y), model)
    end

    sheep.energy -= 1
    if sheep.energy < 0
        remove_agent!(sheep, model)
        return
    end

    # Try to eat grass
    if model.fully_grown[sheep.pos...]
        sheep.energy += sheep.Δenergy
        model.fully_grown[sheep.pos...] = false
    end

    # Try to reproduce
    if rand(abmrng(model)) ≤ sheep.reproduction_prob
        sheep.energy /= 2
        replicate!(sheep, model)
    end
end

function sheepwolf_step_rl!(wolf::Wolf, model, action::Int)
    # Action definitions: 1=stay, 2=north, 3=south, 4=east, 5=west
    current_x, current_y = wolf.pos
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

    # Apply periodic boundary wrapping and move
    if action != 1  # If not staying
        new_x = mod1(current_x + dx, width)
        new_y = mod1(current_y + dy, height)
        move_agent!(wolf, (new_x, new_y), model)
    end

    wolf.energy -= 1
    if wolf.energy < 0
        remove_agent!(wolf, model)
        return
    end

    # Check for sheep to eat
    sheep_ids = [id for id in ids_in_position(wolf.pos, model) if model[id] isa Sheep]
    if !isempty(sheep_ids)
        dinner = model[sheep_ids[1]]
        remove_agent!(dinner, model)
        wolf.energy += wolf.Δenergy
    end

    # Try to reproduce
    if rand(abmrng(model)) ≤ wolf.reproduction_prob
        wolf.energy /= 2
        replicate!(wolf, model)
    end
end

# Wolf-sheep observation function
function get_local_observation(model::ABM, agent_id::Int, observation_radius::Int)
    target_agent = model[agent_id]
    agent_pos = target_agent.pos
    width, height = getfield(model, :space).extent
    agent_type = target_agent isa Sheep ? :sheep : :wolf

    grid_size = 2 * observation_radius + 1
    # 4 channels: sheep_presence, wolf_presence, grass_state, energy_density
    neighborhood_grid = zeros(Float32, grid_size, grid_size, 4, 1)

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
            if neighbor isa Sheep
                neighborhood_grid[grid_x, grid_y, 1, 1] = 1.0  # Sheep presence
                neighborhood_grid[grid_x, grid_y, 4, 1] = Float32(neighbor.energy / 20.0)  # Normalized energy
            elseif neighbor isa Wolf
                neighborhood_grid[grid_x, grid_y, 2, 1] = 1.0  # Wolf presence
                neighborhood_grid[grid_x, grid_y, 4, 1] = Float32(neighbor.energy / 40.0)  # Normalized energy
            end
        end
    end

    # Add grass information
    for dx in -observation_radius:observation_radius
        for dy in -observation_radius:observation_radius
            pos_x = mod1(agent_pos[1] + dx, width)
            pos_y = mod1(agent_pos[2] + dy, height)

            grid_x = dx + observation_radius + 1
            grid_y = dy + observation_radius + 1

            if model.fully_grown[pos_x, pos_y]
                neighborhood_grid[grid_x, grid_y, 3, 1] = 1.0  # Grass available
            end
        end
    end

    # Normalize own agent's data
    max_energy = agent_type == :sheep ? 20.0 : 40.0
    normalized_energy = Float32(target_agent.energy / max_energy)
    normalized_pos = (Float32(agent_pos[1] / width), Float32(agent_pos[2] / height))

    return (
        agent_id=agent_id,
        agent_type=agent_type,
        own_energy=normalized_energy,
        normalized_pos=normalized_pos,
        neighborhood_grid=neighborhood_grid
    )
end

# Wolf-sheep observation to vector function
function observation_to_vector_wolfsheep(obs)
    # Flatten the 4D neighborhood grid
    flattened_grid = vec(obs.neighborhood_grid)

    # Combine all features into a single vector
    return vcat(
        Float32(obs.own_energy),
        Float32(obs.normalized_pos[1]),
        Float32(obs.normalized_pos[2]),
        flattened_grid
    )
end

# Define the agent stepping functions
function wolfsheep_rl_step!(agent, model, action::Int)
    if agent isa Sheep
        sheepwolf_step_rl!(agent, model, action)
    elseif agent isa Wolf
        sheepwolf_step_rl!(agent, model, action)
    end
end

# Define observation function
function wolfsheep_get_observation(model, agent_id, observation_radius)
    return get_local_observation(model, agent_id, observation_radius)
end

# Define reward function
function wolfsheep_calculate_reward(env, agent, action, initial_model, final_model)
    # Check if agent still exists
    if agent.id ∉ [a.id for a in allagents(final_model)]
        return -10.0  # Penalty for dying
    end

    # Reward based on energy and survival
    if agent isa Sheep
        return min(4.0, agent.energy - 4.0)
    else
        return min(4.0, agent.energy / 5.0 - 4.0)
    end
end

# Define terminal condition
function wolfsheep_is_terminal(env)
    agents_of_type = [a for a in allagents(env.abm_model) if typeof(a) == env.current_agent_type]
    return isempty(agents_of_type)
end

# Set up the environment configuration
wolfsheep_obs_radius = 3
wolfsheep_config = (
    model_init_fn=initialize_model_rl,
    agent_step_fn=wolfsheep_rl_step!,
    observation_fn=wolfsheep_get_observation,
    observation_to_vector_fn=observation_to_vector_wolfsheep,
    reward_fn=wolfsheep_calculate_reward,
    terminal_fn=wolfsheep_is_terminal,
    training_agent_types=[Sheep, Wolf],
    action_spaces=Dict(
        Sheep => Crux.DiscreteSpace(5),  # Stay, N, S, E, W
        Wolf => Crux.DiscreteSpace(5)
    ),
    observation_spaces=Dict(
        Sheep => Crux.ContinuousSpace((((2 * wolfsheep_obs_radius + 1)^2 * 4) + 3,), Float32),  # grid + own features
        Wolf => Crux.ContinuousSpace((((2 * wolfsheep_obs_radius + 1)^2 * 4) + 3,), Float32)
    ),
    max_steps=500,
    observation_radius=wolfsheep_obs_radius,
    model_params=Dict(
        :n_sheep => 100,
        :n_wolves => 10,
        :dims => (20, 20)
    )
)

# Train the agents
wolfsheep_policies_sequential, wolfsheep_solvers_sequential = train_agent_sequential([Sheep, Wolf], wolfsheep_config)
wolfsheep_policies_simultaneous, wolfsheep_solvers_simultaneous = train_agent_simultaneous([Sheep, Wolf], wolfsheep_config)


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
boltzmann_policy, boltzmann_solver = train_agent_sequential([BoltzmannAgent], boltzmann_config)
plot_learning(boltzmann_solver[BoltzmannAgent])
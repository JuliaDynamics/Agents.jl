using Agents, Random, Statistics, POMDPs, Crux, Flux, Distributions

## Example 1: Wolf-Sheep Model using NEW ReinforcementLearningABM Interface
# Define Wolf-Sheep RL Agent Types
@agent struct RLSheep(GridAgent{2})
    energy::Float64
    reproduction_prob::Float64
    Δenergy::Float64
end

@agent struct RLWolf(GridAgent{2})
    energy::Float64
    reproduction_prob::Float64
    Δenergy::Float64
end

# Wolf-sheep RL step functions
function sheepwolf_step_rl!(sheep::RLSheep, model, action::Int)
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
        # Check if target position is occupied
        target_pos = (new_x, new_y)

        move_agent!(sheep, target_pos, model)

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
        model.countdown[sheep.pos...] = model.regrowth_time  # Start regrowth timer

    end

    # Try to reproduce
    if rand(abmrng(model)) ≤ sheep.reproduction_prob
        sheep.energy /= 2
        replicate!(sheep, model)
    end
end

# WOLF Step
function sheepwolf_step_rl!(wolf::RLWolf, model, action::Int)
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
    sheep_ids = [id for id in ids_in_position(wolf.pos, model) if haskey(model.agents, id) && model[id] isa RLSheep]
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

function grass_step!(model)
    @inbounds for p in positions(model)
        if !(model.fully_grown[p...])  # If grass is not fully grown
            if model.countdown[p...] ≤ 0
                model.fully_grown[p...] = true  # Regrow grass
            else
                model.countdown[p...] -= 1  # Countdown to regrowth
            end
        end
    end
end

# Define the agent stepping functions for both old and new agent types
function wolfsheep_rl_step!(agent::Union{RLSheep,RLWolf}, model, action::Int)
    #println("DEBUG: wolfsheep_rl_step! called for agent $(agent.id) ($(typeof(agent))) with action $action")
    if agent isa RLSheep
        sheepwolf_step_rl!(agent, model, action)
    elseif agent isa RLWolf
        sheepwolf_step_rl!(agent, model, action)
    end

    # Regrow grass every few steps
    if rand(abmrng(model)) < 0.5  # 50% chance per agent step
        grass_step!(model)
    end
    #println("DEBUG: Agent $(agent.id) step completed - energy: $(agent.energy), pos: $(agent.pos)")
end

function agent_wolfsheep_rl_step!(agent::Union{RLSheep,RLWolf}, model, action::Int)
    #println("DEBUG: wolfsheep_rl_step! called for agent $(agent.id) ($(typeof(agent))) with action $action")
    if agent isa RLSheep
        sheepwolf_step_rl!(agent, model, action)
    elseif agent isa RLWolf
        sheepwolf_step_rl!(agent, model, action)
    end

    #println("DEBUG: Agent $(agent.id) step completed - energy: $(agent.energy), pos: $(agent.pos)")
end


# Wolf-sheep observation function
function get_local_observation(model::ABM, agent_id::Int, observation_radius::Int)
    target_agent = model[agent_id]
    agent_pos = target_agent.pos
    width, height = getfield(model, :space).extent
    agent_type = target_agent isa RLSheep ? :sheep : :wolf

    grid_size = 2 * observation_radius + 1
    neighborhood_grid = zeros(Float32, grid_size, grid_size, 3, 1)

    neighbor_ids = nearby_ids(target_agent, model, observation_radius)
    valid_neighbors = []
    for id in neighbor_ids
        if haskey(model.agents, id) && id != agent_id
            push!(valid_neighbors, model[id])
        end
    end

    for neighbor in valid_neighbors
        dx = neighbor.pos[1] - agent_pos[1]
        dy = neighbor.pos[2] - agent_pos[2]

        if abs(dx) > width / 2
            dx -= sign(dx) * width
        end
        if abs(dy) > height / 2
            dy -= sign(dy) * height
        end

        grid_x = dx + observation_radius + 1
        grid_y = dy + observation_radius + 1

        if 1 <= grid_x <= grid_size && 1 <= grid_y <= grid_size
            if neighbor isa RLSheep
                neighborhood_grid[grid_x, grid_y, 1, 1] = 1.0
                #neighborhood_grid[grid_x, grid_y, 4, 1] = Float32(neighbor.energy / 40.0)  # Use consistent scale
            elseif neighbor isa RLWolf
                neighborhood_grid[grid_x, grid_y, 2, 1] = 1.0
                #neighborhood_grid[grid_x, grid_y, 4, 1] = Float32(neighbor.energy / 40.0)  # Use consistent scale
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
                neighborhood_grid[grid_x, grid_y, 3, 1] = 1.0
            end
        end
    end

    # Use consistent normalization for own energy
    normalized_energy = Float32(target_agent.energy / 40.0)  # Consistent scale
    normalized_pos = (Float32(agent_pos[1] / width), Float32(agent_pos[2] / height))

    return (
        agent_id=agent_id,
        agent_type=agent_type,
        own_energy=normalized_energy,
        normalized_pos=normalized_pos,
        neighborhood_grid=neighborhood_grid
    )
end

# Wolf-sheep observation function that returns vectors directly
function wolfsheep_get_observation(model, agent_id, observation_radius)
    observation_data = get_local_observation(model, agent_id, observation_radius)

    # Convert observation to vector directly
    flattened_grid = vec(observation_data.neighborhood_grid)

    # Combine all features into a single vector
    return vcat(
        Float32(observation_data.own_energy),
        Float32(observation_data.normalized_pos[1]),
        Float32(observation_data.normalized_pos[2]),
        Float32(observation_data.agent_type == :sheep ? 1.0 : 0.0),  # Add agent type indicator
        flattened_grid
    )
end

# Define reward function
function wolfsheep_calculate_reward(env, agent, action, initial_model, final_model)
    # Check if agent still exists
    if agent.id ∉ [a.id for a in allagents(final_model)]
        return -50.0  # Strong death penalty
    end

    if agent isa RLSheep
        # Reward for staying alive and having energy
        reward = 1.0  # Survival bonus
        energy_ratio = agent.energy / 20.0  # Normalize by reasonable max energy
        reward += energy_ratio * 0.5

        # Bonus for eating grass (if energy increased)
        if haskey(initial_model.agents, agent.id)
            initial_energy = initial_model[agent.id].energy
            if agent.energy > initial_energy
                reward += 0.5  # Eating bonus
            end
        end

        return reward
    else  # Wolf
        reward = 1.0  # Survival bonus
        energy_ratio = agent.energy / 40.0  # Wolves can have higher energy
        reward += energy_ratio * 0.3

        # Bonus for eating sheep
        if haskey(initial_model.agents, agent.id)
            initial_energy = initial_model[agent.id].energy
            if agent.energy > initial_energy + 10
                reward += 0.5
            end
        end

        return reward
    end
end

# Define terminal condition for RL model
function wolfsheep_is_terminal_rl(env)
    sheep_count = length([a for a in allagents(env) if a isa RLSheep])
    wolf_count = length([a for a in allagents(env) if a isa RLWolf])
    #println("DEBUG: Sheep count: $sheep_count, Wolf count: $wolf_count")
    return sheep_count == 0 || wolf_count == 0
end

function create_fresh_wolfsheep_model(n_sheeps, n_wolves, dims, regrowth_time, Δenergy_sheep,
    Δenergy_wolf, sheep_reproduce, wolf_reproduce, seed)
    rng = MersenneTwister(seed)
    space = GridSpace(dims, periodic=true)
    properties = Dict{Symbol,Any}(
        :fully_grown => falses(dims),
        :countdown => zeros(Int, dims),
        :regrowth_time => regrowth_time,
    )

    # Create the ReinforcementLearningABM
    model = ReinforcementLearningABM(Union{RLSheep,RLWolf}, space;
        agent_step=agent_wolfsheep_rl_step!, model_step=grass_step!,
        properties=properties, rng=rng,
        scheduler=Schedulers.fastest)

    # Add agents
    for _ in 1:n_sheeps
        energy = rand(abmrng(model), 1:(Δenergy_sheep*2)) - 1
        add_agent!(RLSheep, model, energy, sheep_reproduce, Δenergy_sheep)
    end
    for _ in 1:n_wolves
        energy = rand(abmrng(model), 1:(Δenergy_wolf*2)) - 1
        add_agent!(RLWolf, model, energy, wolf_reproduce, Δenergy_wolf)
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

# Initialize model function for RL ABM
function initialize_rl_model(; n_sheeps=30, n_wolves=5, dims=(10, 10), regrowth_time=10,
    Δenergy_sheep=5, Δenergy_wolf=20, sheep_reproduce=0.2, wolf_reproduce=0.05, observation_radius=4, seed=1234)

    # RL configuration for the model
    rl_config = (
        model_init_fn=() -> create_fresh_wolfsheep_model(n_sheeps, n_wolves, dims, regrowth_time, Δenergy_sheep, Δenergy_wolf, sheep_reproduce, wolf_reproduce, seed),
        observation_fn=wolfsheep_get_observation,
        reward_fn=wolfsheep_calculate_reward,
        terminal_fn=wolfsheep_is_terminal_rl,
        agent_step_fn=wolfsheep_rl_step!,
        action_spaces=Dict(
            RLSheep => Crux.DiscreteSpace(5),  # Stay, N, S, E, W
            RLWolf => Crux.DiscreteSpace(5)
        ),
        observation_spaces=Dict(
            RLSheep => Crux.ContinuousSpace((((2 * observation_radius + 1)^2 * 3) + 4,), Float32),
            RLWolf => Crux.ContinuousSpace((((2 * observation_radius + 1)^2 * 3) + 4,), Float32)
        ),
        training_agent_types=[RLSheep, RLWolf],
        max_steps=300,
        observation_radius=observation_radius,
        discount_rates=Dict(
            RLSheep => 0.99,
            RLWolf => 0.99
        )
    )

    model = create_fresh_wolfsheep_model(n_sheeps, n_wolves, dims, regrowth_time, Δenergy_sheep,
        Δenergy_wolf, sheep_reproduce, wolf_reproduce, seed)

    set_rl_config!(model, rl_config)

    return model
end

# Create the model
rl_model = initialize_rl_model(n_sheeps=100, n_wolves=25, dims=(20, 20), regrowth_time=30,
    Δenergy_sheep=4, Δenergy_wolf=20, sheep_reproduce=0.04, wolf_reproduce=0.05, seed=1234)

println("Created ReinforcementLearningABM with $(nagents(rl_model)) agents")
println("Sheep: $(length([a for a in allagents(rl_model) if a isa RLSheep]))")
println("Wolves: $(length([a for a in allagents(rl_model) if a isa RLWolf]))")

try
    train_model!(rl_model, [RLSheep, RLWolf];
        training_mode=:simultaneous,
        n_iterations=5,
        batch_size=100 * nagents(rl_model),
        solver_params=Dict(
            :ΔN => 10 * nagents(rl_model),
            :log => (period=10 * nagents(rl_model),),
            :max_steps => 25 * nagents(rl_model)
        ))
    println("DEBUG: Training completed successfully")
catch e
    println("DEBUG: Training failed with error: $e")
    println("DEBUG: Error type: $(typeof(e))")
    rethrow(e)
end

#plot_learning(rl_model.training_history[RLSheep])
#plot_learning(rl_model.training_history[RLWolf])


# Create a fresh model instance for simulation with the same parameters
println("\nCreating fresh Wolf-Sheep model for simulation...")
fresh_ws_model = initialize_rl_model(n_sheeps=100, n_wolves=25, dims=(20, 20), regrowth_time=30,
    Δenergy_sheep=4, Δenergy_wolf=20, sheep_reproduce=0.04, wolf_reproduce=0.05, seed=1234)

# Copy the trained policies to the fresh model
copy_trained_policies!(fresh_ws_model, rl_model)
println("DEBUG: Applied trained policies to fresh model")
println("DEBUG: Fresh model has policies for: $(keys(fresh_ws_model.trained_policies))")

using CairoMakie
CairoMakie.activate!()
fig, ax = abmplot(fresh_ws_model)
display(fig)

# Run simulation with trained agents on the fresh model
println("\nRunning simulation with trained RL agents...")
initial_sheep = length([a for a in allagents(fresh_ws_model) if a isa RLSheep])
initial_wolves = length([a for a in allagents(fresh_ws_model) if a isa RLWolf])
println("DEBUG: Initial populations - Sheep: $initial_sheep, Wolves: $initial_wolves")

# Step using RL policies
try
    Agents.step!(fresh_ws_model, 100)
catch e
    println("DEBUG: step_rl! failed with error: $e")
    println("DEBUG: Error type: $(typeof(e))")
    rethrow(e)
end

final_sheep = length([a for a in allagents(fresh_ws_model) if a isa RLSheep])
final_wolves = length([a for a in allagents(fresh_ws_model) if a isa RLWolf])

println("Initial -> Final populations:")
println("Sheep: $initial_sheep -> $final_sheep")
println("Wolves: $initial_wolves -> $final_wolves")

println("\nWolf-Sheep ReinforcementLearningABM example completed!")

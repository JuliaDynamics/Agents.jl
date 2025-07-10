using Agents, Random, CairoMakie, POMDPs, Crux, Flux, Distributions

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

function initialize_model(;
    n_sheep=100,
    n_wolves=50,
    dims=(20, 20),
    regrowth_time=30,
    Δenergy_sheep=4,
    Δenergy_wolf=20,
    sheep_reproduce=0.04,
    wolf_reproduce=0.05,
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
        (agent_step!)=sheepwolf_step!, (model_step!)=grass_step!,
        properties, rng, scheduler=Schedulers.Randomly(), warn=false
    )
    ## Add agents
    for _ in 1:n_sheep
        energy = rand(abmrng(model), 1:(Δenergy_sheep*2)) - 1
        add_agent!(Sheep, model, energy, sheep_reproduce, Δenergy_sheep)
    end
    for _ in 1:n_wolves
        energy = rand(abmrng(model), 1:(Δenergy_wolf*2)) - 1
        add_agent!(Wolf, model, energy, wolf_reproduce, Δenergy_wolf)
    end
    ## Add grass with random initial growth
    for p in positions(model)
        fully_grown = rand(abmrng(model), Bool)
        countdown = fully_grown ? regrowth_time : rand(abmrng(model), 1:regrowth_time) - 1
        model.countdown[p...] = countdown
        model.fully_grown[p...] = fully_grown
    end
    return model
end

### Defining the stepping functions
# Original random behavior functions
function sheepwolf_step_random!(sheep::Sheep, model)
    randomwalk!(sheep, model)
    sheep.energy -= 1
    if sheep.energy < 0
        remove_agent!(sheep, model)
        return
    end
    eat!(sheep, model)
    if rand(abmrng(model)) ≤ sheep.reproduction_prob
        sheep.energy /= 2
        replicate!(sheep, model)
    end
end

function sheepwolf_step_random!(wolf::Wolf, model)
    randomwalk!(wolf, model; ifempty=false)
    wolf.energy -= 1
    if wolf.energy < 0
        remove_agent!(wolf, model)
        return
    end
    dinner = first_sheep_in_position(wolf.pos, model)
    !isnothing(dinner) && eat!(wolf, dinner, model)
    if rand(abmrng(model)) ≤ wolf.reproduction_prob
        wolf.energy /= 2
        replicate!(wolf, model)
    end
end

# RL-based stepping functions
function sheepwolf_step_rl!(sheep::Sheep, model, action::Int)
    # Action definitions for sheep:
    # 1: Stay, 2: North, 3: South, 4: East, 5: West
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

    eat!(sheep, model)

    # Try to reproduce 
    if rand(abmrng(model)) ≤ sheep.reproduction_prob
        sheep.energy /= 2
        replicate!(sheep, model)
    end
end

function sheepwolf_step_rl!(wolf::Wolf, model, action::Int)
    # Action definitions for wolf:
    # 1: Stay, 2: North, 3: South, 4: East, 5: West
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
    dinner = first_sheep_in_position(wolf.pos, model)
    if !isnothing(dinner)
        eat!(wolf, dinner, model)
    end

    # Try to reproduce
    if rand(abmrng(model)) ≤ wolf.reproduction_prob
        wolf.energy /= 2
        replicate!(wolf, model)
    end
end

# Default stepping function (for non-RL simulations)
sheepwolf_step!(agent, model) = sheepwolf_step_random!(agent, model)

function first_sheep_in_position(pos, model)
    ids = ids_in_position(pos, model)
    j = findfirst(id -> model[id] isa Sheep, ids)
    isnothing(j) ? nothing : model[ids[j]]::Sheep
end

# Sheep and wolves have separate `eat!` functions. If a sheep eats grass, it will acquire
# additional energy and the grass will not be available for consumption until regrowth time
# has elapsed. If a wolf eats a sheep, the sheep dies and the wolf acquires more energy.
function eat!(sheep::Sheep, model)
    if model.fully_grown[sheep.pos...]
        sheep.energy += sheep.Δenergy
        model.fully_grown[sheep.pos...] = false
    end
    return
end

function eat!(wolf::Wolf, sheep::Sheep, model)
    remove_agent!(sheep, model)
    wolf.energy += wolf.Δenergy
    return
end

# The behavior of grass function differently. If it is fully grown, it is consumable.
# Otherwise, it cannot be consumed until it regrows after a delay specified by
# `regrowth_time`. The dynamics of the grass is our `model_step!` function.
function grass_step!(model)
    @inbounds for p in positions(model)
        if !(model.fully_grown[p...])
            if model.countdown[p...] ≤ 0
                model.fully_grown[p...] = true
                model.countdown[p...] = model.regrowth_time
            else
                model.countdown[p...] -= 1
            end
        end
    end
end

## RL Environment Setup

# Define action spaces for each agent type
const SHEEP_ACTIONS = 5  # Stay, North, South, East, West
const WOLF_ACTIONS = 5   # Stay, North, South, East, West

# State representation for the environment
mutable struct WolfSheepState
    sheep_data::Vector{Tuple{Int,Int,Float64}}  # (x, y, energy) for each sheep
    wolf_data::Vector{Tuple{Int,Int,Float64}}   # (x, y, energy) for each wolf
    grass_data::Matrix{Bool}                    # grass state for each position
    step_count::Int
    n_sheep::Int
    n_wolves::Int
end

# Local observation for an individual agent
mutable struct LocalObservation
    agent_id::Int
    agent_type::Symbol  # :sheep or :wolf
    own_energy::Float32
    normalized_pos::Tuple{Float32,Float32}
    neighborhood_grid::Array{Float32,4}  # (width, height, channels, 1)
end

# Helper to convert model to state
function model_to_state(model::ABM, step_count::Int)
    sheep_data = [(a.pos[1], a.pos[2], a.energy) for a in allagents(model) if a isa Sheep]
    wolf_data = [(a.pos[1], a.pos[2], a.energy) for a in allagents(model) if a isa Wolf]
    grass_data = copy(model.fully_grown)
    n_sheep = length(sheep_data)
    n_wolves = length(wolf_data)

    return WolfSheepState(sheep_data, wolf_data, grass_data, step_count, n_sheep, n_wolves)
end

# Get local observation for a specific agent
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

    return LocalObservation(agent_id, agent_type, normalized_energy, normalized_pos, neighborhood_grid)
end

# Convert local observation to vector
function observation_to_vector(obs::LocalObservation)::Vector{Float32}
    # Flatten the 4D neighborhood grid
    flattened_grid = vec(obs.neighborhood_grid)

    # Combine all features into a single vector
    return vcat(
        obs.own_energy,
        obs.normalized_pos[1],
        obs.normalized_pos[2],
        flattened_grid
    )
end

## Multi-Agent RL Environment for Wolf-Sheep

# Environment that manages both sheep and wolf policies
mutable struct WolfSheepEnv <: POMDP{Vector{Float32},Int,Vector{Float32}}
    abm_model::ABM
    dims::Tuple{Int,Int}
    max_steps::Int
    observation_radius::Int
    current_agent_id::Int
    current_agent_type::Symbol
    rng::AbstractRNG
    sheep_policy::Union{Nothing,Any}  # Will hold trained sheep policy
    wolf_policy::Union{Nothing,Any}   # Will hold trained wolf policy
    training_agent_type::Symbol       # Which type we're currently training
    step_count::Int                   # Tracks steps
    n_sheep::Int                      # Initial number of sheep
    n_wolves::Int                     # Initial number of wolves
end

# Constructor for WolfSheepEnv
function WolfSheepEnv(;
    n_sheep=100,
    n_wolves=10,
    dims=(15, 15),
    seed=123,
    max_steps=500,
    observation_radius=2,
    training_agent_type=:sheep
)
    rng = MersenneTwister(seed)
    model = initialize_model_rl(
        n_sheep=n_sheep,
        n_wolves=n_wolves,
        dims=dims,
        seed=seed,
        observation_radius=observation_radius
    )

    env = WolfSheepEnv(
        model,
        dims,
        max_steps,
        observation_radius,
        1,  # Start with first agent
        training_agent_type,
        rng,
        nothing,  # No policies initially
        nothing,
        training_agent_type,
        0,  # Initialize step count
        n_sheep,  # Store initial sheep count
        n_wolves  # Store initial wolf count
    )
    return env
end

# Initialize model specifically for RL training
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
    observation_radius=2
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

# Get the current agent for training
function get_current_training_agent(env::WolfSheepEnv)
    agents_of_type = [a for a in allagents(env.abm_model) if
                      (env.training_agent_type == :sheep && a isa Sheep) ||
                      (env.training_agent_type == :wolf && a isa Wolf)]

    if isempty(agents_of_type)
        return nothing
    end

    # Cycle through agents of the training type
    agent_idx = ((env.current_agent_id - 1) % length(agents_of_type)) + 1
    return agents_of_type[agent_idx]
end

# Implement POMDPs.jl interface
function POMDPs.actions(env::WolfSheepEnv)
    if env.training_agent_type == :sheep
        return Crux.DiscreteSpace(SHEEP_ACTIONS)
    else
        return Crux.DiscreteSpace(WOLF_ACTIONS)
    end
end

function POMDPs.observations(env::WolfSheepEnv)
    grid_size = 2 * env.observation_radius + 1
    # 3 (own_energy + normalized_pos) + grid_size * grid_size * 4 (4 channels)
    obs_dims = 3 + (grid_size^2 * 4)
    return Crux.ContinuousSpace((obs_dims,), Float32)
end

function POMDPs.observation(env::WolfSheepEnv, s::Vector{Float32})
    current_agent = get_current_training_agent(env)
    if isnothing(current_agent)
        # Return a zero observation if no agent available
        obs_dims = 3 + ((2 * env.observation_radius + 1)^2 * 4)
        return zeros(Float32, obs_dims)
    end

    local_obs = get_local_observation(env.abm_model, current_agent.id, env.observation_radius)
    return observation_to_vector(local_obs)
end

function POMDPs.initialstate(env::WolfSheepEnv)
    env.abm_model = initialize_model_rl(
        n_sheep=env.n_sheep,
        n_wolves=env.n_wolves,
        dims=env.dims,
        seed=rand(env.rng, Int),
        observation_radius=env.observation_radius
    )
    env.current_agent_id = 1
    env.step_count = 0  # Reset step count

    # Return a dummy state vector - we use observations
    return Dirac(zeros(Float32, 10))
end

function POMDPs.initialobs(env::WolfSheepEnv, initial_state::Vector{Float32})
    obs = POMDPs.observation(env, initial_state)
    return Dirac(obs)
end

function POMDPs.gen(env::WolfSheepEnv, s, action::Int, rng::AbstractRNG)
    current_agent = get_current_training_agent(env)

    if isnothing(current_agent)
        # Episode terminated - no agents left
        obs_dims = 3 + ((2 * env.observation_radius + 1)^2 * 4)
        return (sp=s, o=zeros(Float32, obs_dims), r=-10.0)
    end

    # Record initial state for reward calculation
    initial_sheep_count = count(a -> a isa Sheep, allagents(env.abm_model))
    initial_wolf_count = count(a -> a isa Wolf, allagents(env.abm_model))
    initial_agent_energy = current_agent.energy

    # Execute the action
    if current_agent isa Sheep
        sheepwolf_step_rl!(current_agent, env.abm_model, action)
    else
        sheepwolf_step_rl!(current_agent, env.abm_model, action)
    end

    # Calculate reward based on agent type and survival
    reward = calculate_reward(env, current_agent, action, initial_agent_energy,
        initial_sheep_count, initial_wolf_count)

    # Advance to next agent and run environmental step
    advance_simulation(env)

    # Return next state and observation
    sp = s  # Use dummy state
    o = observation(env, sp)

    return (sp=sp, o=o, r=reward)
end

function calculate_reward(env::WolfSheepEnv, agent, action::Int,
    initial_energy::Float64, initial_sheep_count::Int, initial_wolf_count::Int)
    # Check if agent still exists
    if agent.id ∉ [a.id for a in allagents(env.abm_model)]
        return -10.0  # Penalty for dying
    end

    # Agents are rewarded for being alive and having energy
    if agent isa Sheep
        return min(4.0, agent.energy - 4.0)
    else
        return min(4.0, agent.energy / 5.0 - 4.0)
    end
end

function advance_simulation(env::WolfSheepEnv)
    # Move to next agent of the training type
    agents_of_type = [a for a in allagents(env.abm_model) if
                      (env.training_agent_type == :sheep && a isa Sheep) ||
                      (env.training_agent_type == :wolf && a isa Wolf)]

    if !isempty(agents_of_type)
        env.current_agent_id += 1

        # If we've cycled through all agents of this type, run other agents and environment step
        if env.current_agent_id > length(agents_of_type)
            env.current_agent_id = 1

            # Run other agent type with trained policy if available, otherwise random
            other_agents = [a for a in allagents(env.abm_model) if
                            (env.training_agent_type == :sheep && a isa Wolf) ||
                            (env.training_agent_type == :wolf && a isa Sheep)]

            for other_agent in other_agents
                try
                    if other_agent isa Sheep && !isnothing(env.sheep_policy)
                        # Use trained sheep policy
                        obs = get_local_observation(env.abm_model, other_agent.id, env.observation_radius)
                        obs_vec = observation_to_vector(obs)
                        action = Crux.action(env.sheep_policy, obs_vec)
                        sheepwolf_step_rl!(other_agent, env.abm_model, action)
                    elseif other_agent isa Wolf && !isnothing(env.wolf_policy)
                        # Use trained wolf policy
                        obs = get_local_observation(env.abm_model, other_agent.id, env.observation_radius)
                        obs_vec = observation_to_vector(obs)
                        action = Crux.action(env.wolf_policy, obs_vec)
                        sheepwolf_step_rl!(other_agent, env.abm_model, action)
                    else
                        # Fall back to random behavior
                        if other_agent isa Sheep
                            sheepwolf_step_random!(other_agent, env.abm_model)
                        else
                            sheepwolf_step_random!(other_agent, env.abm_model)
                        end
                    end
                catch e
                    # Agent might have died during action, continue
                    continue
                end
            end

            # Run grass step
            grass_step!(env.abm_model)
            env.step_count += 1
        end
    end
end

function POMDPs.isterminal(env::WolfSheepEnv, s)
    # Terminal if no agents of training type left or max steps reached
    agents_of_type = [a for a in allagents(env.abm_model) if
                      (env.training_agent_type == :sheep && a isa Sheep) ||
                      (env.training_agent_type == :wolf && a isa Wolf)]

    return isempty(agents_of_type) || env.step_count >= env.max_steps
end

Crux.state_space(env::WolfSheepEnv) = Crux.ContinuousSpace((10,))  # Dummy state space
POMDPs.discount(env::WolfSheepEnv) = 0.99

## Training Setup
N_SHEEPS = 100
N_WOLVES = 10
OBSERVATION_RADIUS = 4
# Setup environments for training each agent type
function setup_sheep_training(training_steps=50_000)
    env = WolfSheepEnv(training_agent_type=:sheep, n_sheep=N_SHEEPS, n_wolves=N_WOLVES, dims=(20, 20), observation_radius=OBSERVATION_RADIUS)

    S = Crux.state_space(env)
    O = observations(env)
    as = POMDPs.actions(env).vals

    # Define neural network for sheep policy
    V() = ContinuousNetwork(Chain(Dense(Crux.dim(O)..., 64, relu), Dense(64, 64, relu), Dense(64, 1)))
    B() = DiscreteNetwork(Chain(Dense(Crux.dim(O)..., 64, relu), Dense(64, 64, relu), Dense(64, length(as))), as)

    solver = PPO(
        π=ActorCritic(B(), V()),
        S=O,
        N=training_steps,
        ΔN=500,
        log=(period=1000,)
    )
    return env, solver
end

function setup_wolf_training(training_steps=50_000)
    env = WolfSheepEnv(training_agent_type=:wolf, n_sheep=N_SHEEPS, n_wolves=N_WOLVES, dims=(20, 20), observation_radius=OBSERVATION_RADIUS)

    S = Crux.state_space(env)
    O = observations(env)
    as = POMDPs.actions(env).vals

    # Define neural network for wolf policy
    V() = ContinuousNetwork(Chain(Dense(Crux.dim(O)..., 64, relu), Dense(64, 64, relu), Dense(64, 1)))
    B() = DiscreteNetwork(Chain(Dense(Crux.dim(O)..., 64, relu), Dense(64, 64, relu), Dense(64, length(as))), as)

    solver = PPO(
        π=ActorCritic(B(), V()),
        S=O,
        N=training_steps,
        ΔN=500,
        log=(period=1000,)
    )
    return env, solver
end

# Example training workflow with alternating policy updates
function train_agents()
    println("Training agents with alternating policy updates...")

    # Phase 1: Train sheep with random wolves
    println("Phase 1: Training sheep policy with random wolves...")
    sheep_env, sheep_solver = setup_sheep_training()
    sheep_policy = solve(sheep_solver, sheep_env)

    # Phase 2: Train wolves using the trained sheep policy
    println("Phase 2: Training wolf policy with trained sheep...")
    wolf_env, wolf_solver = setup_wolf_training()
    # Inject the trained sheep policy into the wolf training environment
    wolf_env.sheep_policy = sheep_policy
    wolf_policy = solve(wolf_solver, wolf_env)

    # Phase 3: Fine-tune sheep policy with trained wolves
    println("Phase 3: Fine-tuning sheep policy with trained wolves...")
    sheep_env_fine, sheep_solver_fine = setup_sheep_training()
    # Inject the trained wolf policy
    sheep_env_fine.wolf_policy = wolf_policy
    # Reduce training steps for fine-tuning
    sheep_solver_fine.N = 25_000
    sheep_policy_final = solve(sheep_solver_fine, sheep_env_fine)

    return sheep_policy_final, wolf_policy
end

# Alternative: Train both policies simultaneously with periodic updates
function train_agents_simultaneous(n_iterations=5, batch_size=10_000)
    println("Training agents with simultaneous policy updates...")

    # Initialize both environments
    sheep_env, sheep_solver = setup_sheep_training()
    wolf_env, wolf_solver = setup_wolf_training()

    # Train in alternating batches
    sheep_policy = nothing
    wolf_policy = nothing

    for iter in 1:n_iterations
        println("Iteration $iter/$n_iterations")

        # Update sheep solver for this iteration
        sheep_solver.N = batch_size
        if !isnothing(wolf_policy)
            sheep_env.wolf_policy = wolf_policy
        end

        println("  Training sheep...")
        sheep_policy = solve(sheep_solver, sheep_env)

        # Update wolf solver for this iteration  
        wolf_solver.N = batch_size
        if !isnothing(sheep_policy)
            wolf_env.sheep_policy = sheep_policy
        end

        println("  Training wolf...")
        wolf_policy = solve(wolf_solver, wolf_env)
    end

    return sheep_policy, wolf_policy
end

# Simulation with trained policies vs random behavior
function run_rl_simulation(sheep_policy, wolf_policy; steps=500, observation_radius=OBSERVATION_RADIUS, compare_with_random=true)
    println("=== RL vs Random Behavior Comparison ===")

    if compare_with_random
        # Run random behavior simulation first
        println("\n--- Running Random Behavior Simulation ---")
        model_random = initialize_model_rl(n_sheep=N_SHEEPS, n_wolves=N_WOLVES, dims=(20, 20), observation_radius=observation_radius, seed=12345)

        random_populations = Tuple{Int,Int}[]

        for step in 1:steps
            all_agents = collect(allagents(model_random))

            for agent in all_agents
                try
                    if agent isa Sheep
                        sheepwolf_step_random!(agent, model_random)
                    else
                        sheepwolf_step_random!(agent, model_random)
                    end
                catch e
                    continue
                end
            end

            grass_step!(model_random)

            n_sheep = count(a -> a isa Sheep, allagents(model_random))
            n_wolves = count(a -> a isa Wolf, allagents(model_random))
            push!(random_populations, (n_sheep, n_wolves))

            if step % 50 == 0
                println("Random Step $step: Sheep=$n_sheep, Wolves=$n_wolves")
            end

            # Early termination if ecosystem collapses
            if n_sheep == 0 || n_wolves == 0
                println("Random: Ecosystem collapsed at step $step")
                break
            end
        end

        println("Random simulation completed. Final: Sheep=$(random_populations[end][1]), Wolves=$(random_populations[end][2])")
    end

    # Run RL policy simulation
    println("\n--- Running RL Policy Simulation ---")
    model_rl = initialize_model_rl(n_sheep=N_SHEEPS, n_wolves=N_WOLVES, dims=(20, 20), observation_radius=observation_radius, seed=12345)

    rl_populations = Tuple{Int,Int}[]

    for step in 1:steps
        all_agents = collect(allagents(model_rl))

        for agent in all_agents
            try
                if agent isa Sheep && !isnothing(sheep_policy)
                    # Get observation and action from sheep policy
                    obs = get_local_observation(model_rl, agent.id, observation_radius)
                    obs_vec = observation_to_vector(obs)
                    action = Crux.action(sheep_policy, obs_vec)
                    sheepwolf_step_rl!(agent, model_rl, action[1])
                elseif agent isa Wolf && !isnothing(wolf_policy)
                    # Get observation and action from wolf policy
                    obs = get_local_observation(model_rl, agent.id, observation_radius)
                    obs_vec = observation_to_vector(obs)
                    action = Crux.action(wolf_policy, obs_vec)
                    sheepwolf_step_rl!(agent, model_rl, action[1])
                else
                    # Fall back to random behavior
                    if agent isa Sheep
                        sheepwolf_step_random!(agent, model_rl)
                    else
                        sheepwolf_step_random!(agent, model_rl)
                    end
                end
            catch e
                continue
            end
        end

        grass_step!(model_rl)

        n_sheep = count(a -> a isa Sheep, allagents(model_rl))
        n_wolves = count(a -> a isa Wolf, allagents(model_rl))
        push!(rl_populations, (n_sheep, n_wolves))

        if step % 50 == 0
            println("RL Step $step: Sheep=$n_sheep, Wolves=$n_wolves")
        end

        # Early termination if ecosystem collapses
        if n_sheep == 0 || n_wolves == 0
            println("RL: Ecosystem collapsed at step $step")
            break
        end
    end

    println("RL simulation completed. Final: Sheep=$(rl_populations[end][1]), Wolves=$(rl_populations[end][2])")

    # Comparison analysis
    if compare_with_random && !isempty(random_populations) && !isempty(rl_populations)
        println("\n=== Comparison Results ===")

        # Survival analysis
        random_survived = length(random_populations) >= steps * 0.8  # Survived 80% of simulation
        rl_survived = length(rl_populations) >= steps * 0.8

        println("Survival Analysis:")
        println("  Random behavior survived full simulation: $random_survived")
        println("  RL policies survived full simulation: $rl_survived")

        if random_survived && rl_survived
            # Population stability comparison
            random_final = random_populations[end]
            rl_final = rl_populations[end]

            println("\nFinal Populations:")
            println("  Random: Sheep=$(random_final[1]), Wolves=$(random_final[2]), Ratio=$(round(random_final[1]/max(random_final[2],1), digits=2))")
            println("  RL: Sheep=$(rl_final[1]), Wolves=$(rl_final[2]), Ratio=$(round(rl_final[1]/max(rl_final[2],1), digits=2))")
        end

        return (rl_model=model_rl, random_model=compare_with_random ? model_random : nothing,
            rl_populations=rl_populations, random_populations=compare_with_random ? random_populations : nothing)
    end

    return model_rl
end


# Uncomment to run training:
sheep_policy, wolf_policy = train_agents()  # Sequential training with policy updates
# sheep_policy, wolf_policy = train_agents_simultaneous(10, 5000)  # Alternating batch training
final_model = run_rl_simulation(sheep_policy, wolf_policy, steps=500)

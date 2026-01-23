# # Predator-Prey Model with Reinforcement Learning

# This example demonstrates how to integrate reinforcement learning (RL) with 
# the classic predator-prey model. Building on the traditional Wolf-Sheep model,
# this version replaces random movement with learned behavior, where agents use
# reinforcement learning to optimize their survival and reproduction strategies.

# The model showcases how RL agents can learn complex behaviors in multi-species
# ecosystems, with wolves learning to hunt efficiently and sheep learning to
# avoid predators while foraging for grass.

# ## Model specification

# This model extends the classic predator-prey dynamics with reinforcement learning:

# **Environment:**
# - 2D periodic grid with grass that regrows over time
# - Wolves hunt sheep for energy
# - Sheep eat grass for energy
# - Both species can reproduce when they have sufficient energy

# **RL Integration:**
# - **Actions**: Stay, move North, South, East, or West (5 discrete actions)
# - **Observations**: Local neighborhood information including other agents, grass, and own energy
# - **Rewards**: Survival, energy maintenance, successful feeding, and reproduction
# - **Goal**: Learn optimal movement and foraging/hunting strategies

# **Key differences from traditional model:**
# - Movement decisions are learned rather than random
# - Agents can develop sophisticated strategies over time
# - Emergent behaviors arise from individual learning rather than hard-coded rules

# ## Loading packages and defining agent types

# ```julia
# using Agents, Random, Statistics, POMDPs, Crux, Flux, Distributions
# 
# @agent struct RLSheep(GridAgent{2})
#     energy::Float64
#     reproduction_prob::Float64
#     Δenergy::Float64
# end
# 
# @agent struct RLWolf(GridAgent{2})
#     energy::Float64
#     reproduction_prob::Float64
#     Δenergy::Float64
# end
# ```

# ## Agent stepping functions

# The stepping functions define how agents behave in response to RL actions.
# Unlike the traditional model with random movement, here movement is determined
# by the RL policy based on the learned strategy.

# ### Sheep stepping function

# Sheep must balance energy conservation, grass foraging, and predator avoidance.

# ```julia
# # Wolf-sheep RL step functions
# function sheepwolf_step_rl!(sheep::RLSheep, model, action::Int)
#     # Action definitions: 1=stay, 2=north, 3=south, 4=east, 5=west
#     current_x, current_y = sheep.pos
#     width, height = getfield(model, :space).extent
# 
#     dx, dy = 0, 0
#     if action == 2      # North
#         dy = 1
#     elseif action == 3  # South
#         dy = -1
#     elseif action == 4  # East
#         dx = 1
#     elseif action == 5  # West
#         dx = -1
#     end
# 
#     # Apply periodic boundary wrapping and move
#     if action != 1  # If not staying
#         new_x = mod1(current_x + dx, width)
#         new_y = mod1(current_y + dy, height)
#         target_pos = (new_x, new_y)
#         move_agent!(sheep, target_pos, model)
#     end
# 
#     # Energy decreases with each step (movement cost)
#     sheep.energy -= 1
#     if sheep.energy < 0
#         remove_agent!(sheep, model)
#         return
#     end
# 
#     # Try to eat grass if available
#     if model.fully_grown[sheep.pos...]
#         sheep.energy += sheep.Δenergy
#         model.fully_grown[sheep.pos...] = false
#         model.countdown[sheep.pos...] = model.regrowth_time
#     end
# 
#     # Reproduce if energy is sufficient
#     if rand(abmrng(model)) ≤ sheep.reproduction_prob
#         sheep.energy /= 2
#         replicate!(sheep, model)
#     end
# end
# ```

# ### Wolf stepping function

# Wolves must learn efficient hunting strategies while managing their energy reserves.

# ```julia
# # WOLF Step
# function sheepwolf_step_rl!(wolf::RLWolf, model, action::Int)
#     # Action definitions: 1=stay, 2=north, 3=south, 4=east, 5=west
#     current_x, current_y = wolf.pos
#     width, height = getfield(model, :space).extent
# 
#     dx, dy = 0, 0
#     if action == 2      # North
#         dy = 1
#     elseif action == 3  # South
#         dy = -1
#     elseif action == 4  # East
#         dx = 1
#     elseif action == 5  # West
#         dx = -1
#     end
# 
#     # Apply periodic boundary wrapping and move
#     if action != 1  # If not staying
#         new_x = mod1(current_x + dx, width)
#         new_y = mod1(current_y + dy, height)
#         move_agent!(wolf, (new_x, new_y), model)
#     end
# 
#     # Energy decreases with each step
#     wolf.energy -= 1
#     if wolf.energy < 0
#         remove_agent!(wolf, model)
#         return
#     end
# 
#     # Hunt sheep if available at current position
#     sheep_ids = [id for id in ids_in_position(wolf.pos, model) if haskey(model.agents, id) && model[id] isa RLSheep]
#     if !isempty(sheep_ids)
#         dinner = model[sheep_ids[1]]
#         remove_agent!(dinner, model)
#         wolf.energy += wolf.Δenergy
#     end
# 
#     # Reproduce if energy is sufficient
#     if rand(abmrng(model)) ≤ wolf.reproduction_prob
#         wolf.energy /= 2
#         replicate!(wolf, model)
#     end
# end
# ```

# ### Grass dynamics and unified stepping

# Grass regrows over time, providing a renewable resource for sheep.

# ```julia
# function grass_step!(model)
#     @inbounds for p in positions(model)
#         if !(model.fully_grown[p...])  # If grass is not fully grown
#             if model.countdown[p...] ≤ 0
#                 model.fully_grown[p...] = true  # Regrow grass
#             else
#                 model.countdown[p...] -= 1  # Countdown to regrowth
#             end
#         end
#     end
# end
# 
# # Unified stepping function for both agent types
# function wolfsheep_rl_step!(agent::Union{RLSheep,RLWolf}, model, action::Int)
#     if agent isa RLSheep
#         sheepwolf_step_rl!(agent, model, action)
#     elseif agent isa RLWolf
#         sheepwolf_step_rl!(agent, model, action)
#     end
# 
#     # Stochastic grass regrowth
#     if rand(abmrng(model)) < 0.6
#         grass_step!(model)
#     end
# end
# 
# function agent_wolfsheep_rl_step!(agent::Union{RLSheep,RLWolf}, model, action::Int)
#     if agent isa RLSheep
#         sheepwolf_step_rl!(agent, model, action)
#     elseif agent isa RLWolf
#         sheepwolf_step_rl!(agent, model, action)
#     end
# end
# ```

# ## RL-specific functions

# The following functions define how the RL environment interacts with the ABM:
# - **Observation function**: Provides agents with local environmental information
# - **Reward function**: Shapes learning by rewarding desired behaviors  
# - **Terminal function**: Determines when episodes end

# ### Observation function

# Agents observe their local neighborhood, including other agents, grass availability,
# and their own status. This information helps them make informed decisions.

# ```julia
# # Wolf-sheep observation function
# function get_local_observation(model::ABM, agent_id::Int, observation_radius::Int)
#     target_agent = model[agent_id]
#     agent_pos = target_agent.pos
#     width, height = getfield(model, :space).extent
#     agent_type = target_agent isa RLSheep ? :sheep : :wolf
# 
#     grid_size = 2 * observation_radius + 1
#     # 3 channels: sheep, wolves, grass
#     neighborhood_grid = zeros(Float32, grid_size, grid_size, 3, 1)
# 
#     # Get valid neighboring agents
#     neighbor_ids = nearby_ids(target_agent, model, observation_radius)
#     valid_neighbors = []
#     for id in neighbor_ids
#         if haskey(model.agents, id) && id != agent_id
#             push!(valid_neighbors, model[id])
#         end
#     end
# 
#     # Map neighbors to observation grid
#     for neighbor in valid_neighbors
#         dx = neighbor.pos[1] - agent_pos[1]
#         dy = neighbor.pos[2] - agent_pos[2]
# 
#         # Handle periodic boundaries
#         if abs(dx) > width / 2
#             dx -= sign(dx) * width
#         end
#         if abs(dy) > height / 2
#             dy -= sign(dy) * height
#         end
# 
#         grid_x = dx + observation_radius + 1
#         grid_y = dy + observation_radius + 1
# 
#         if 1 <= grid_x <= grid_size && 1 <= grid_y <= grid_size
#             if neighbor isa RLSheep
#                 neighborhood_grid[grid_x, grid_y, 1, 1] = 1.0  # Sheep channel
#             elseif neighbor isa RLWolf
#                 neighborhood_grid[grid_x, grid_y, 2, 1] = 1.0  # Wolf channel
#             end
#         end
#     end
# 
#     # Add grass information to observation
#     for dx in -observation_radius:observation_radius
#         for dy in -observation_radius:observation_radius
#             pos_x = mod1(agent_pos[1] + dx, width)
#             pos_y = mod1(agent_pos[2] + dy, height)
# 
#             grid_x = dx + observation_radius + 1
#             grid_y = dy + observation_radius + 1
# 
#             if model.fully_grown[pos_x, pos_y]
#                 neighborhood_grid[grid_x, grid_y, 3, 1] = 1.0  # Grass channel
#             end
#         end
#     end
# 
#     # Normalize agent's own information
#     normalized_energy = Float32(target_agent.energy / 40.0)
#     normalized_pos = (Float32(agent_pos[1] / width), Float32(agent_pos[2] / height))
# 
#     return (
#         agent_id=agent_id,
#         agent_type=agent_type,
#         own_energy=normalized_energy,
#         normalized_pos=normalized_pos,
#         neighborhood_grid=neighborhood_grid
#     )
# end
# 
# # Convert observation to vector format for neural networks
# function wolfsheep_get_observation(model, agent_id, observation_radius)
#     observation_data = get_local_observation(model, agent_id, observation_radius)
# 
#     # Flatten spatial information
#     flattened_grid = vec(observation_data.neighborhood_grid)
# 
#     # Combine all features into a single observation vector
#     return vcat(
#         Float32(observation_data.own_energy),
#         Float32(observation_data.normalized_pos[1]),
#         Float32(observation_data.normalized_pos[2]),
#         Float32(observation_data.agent_type == :sheep ? 1.0 : 0.0),  # Agent type indicator
#         flattened_grid
#     )
# end
# ```

# ### Reward function

# The reward function shapes agent learning by providing feedback on their actions.
# Different strategies are used for sheep (survival and foraging) vs wolves (hunting).

# ```julia
# # Define reward function
# function wolfsheep_calculate_reward(env, agent, action, initial_model, final_model)
#     # Death penalty - strongest negative reward
#     if agent.id ∉ [a.id for a in allagents(final_model)]
#         return -50.0
#     end
# 
#     if agent isa RLSheep
#         # Sheep rewards: survival, energy maintenance, successful foraging
#         reward = 1.0  # Base survival bonus
# 
#         # Energy level bonus (normalized)
#         energy_ratio = agent.energy / 20.0
#         reward += energy_ratio * 0.5
# 
#         # Bonus for successful foraging (energy increase)
#         if haskey(initial_model.agents, agent.id)
#             initial_energy = initial_model[agent.id].energy
#             if agent.energy > initial_energy
#                 reward += 0.5  # Foraging success bonus
#             end
#         end
# 
#         return reward
# 
#     else  # Wolf
#         # Wolf rewards: survival, energy maintenance, successful hunting
#         reward = 1.0  # Base survival bonus
# 
#         # Energy level bonus (wolves can have higher energy)
#         energy_ratio = agent.energy / 40.0
#         reward += energy_ratio * 0.3
# 
#         # Large bonus for successful hunting (significant energy increase)
#         if haskey(initial_model.agents, agent.id)
#             initial_energy = initial_model[agent.id].energy
#             if agent.energy > initial_energy + 10  # Indicates successful hunt
#                 reward += 0.5  # Hunting success bonus
#             end
#         end
# 
#         return reward
#     end
# end
# ```

# ### Terminal condition

# Episodes end when either species goes extinct, creating natural stopping points
# for learning episodes while maintaining ecological realism.

# ```julia
# # Define terminal condition for RL model
# function wolfsheep_is_terminal_rl(env)
#     sheep_count = length([a for a in allagents(env) if a isa RLSheep])
#     wolf_count = length([a for a in allagents(env) if a isa RLWolf])
#     return sheep_count == 0 || wolf_count == 0
# end
# ```

# ## Model initialization

# The following functions handle model creation and RL configuration setup,
# similar to the traditional wolf-sheep model but with RL capabilities.

# ```julia
# function create_fresh_wolfsheep_model(n_sheeps, n_wolves, dims, regrowth_time, Δenergy_sheep,
#     Δenergy_wolf, sheep_reproduce, wolf_reproduce, seed)
# 
#     rng = MersenneTwister(seed)
#     space = GridSpace(dims, periodic=true)
# 
#     # Model properties for grass dynamics
#     properties = Dict{Symbol,Any}(
#         :fully_grown => falses(dims),
#         :countdown => zeros(Int, dims),
#         :regrowth_time => regrowth_time,
#     )
# 
#     # Create the ReinforcementLearningABM
#     model = ReinforcementLearningABM(Union{RLSheep,RLWolf}, space;
#         agent_step=agent_wolfsheep_rl_step!, model_step=grass_step!,
#         properties=properties, rng=rng,
#         scheduler=Schedulers.Randomly())
# 
#     # Add sheep agents
#     for _ in 1:n_sheeps
#         energy = rand(abmrng(model), 1:(Δenergy_sheep*2)) - 1
#         add_agent!(RLSheep, model, energy, sheep_reproduce, Δenergy_sheep)
#     end
# 
#     # Add wolf agents
#     for _ in 1:n_wolves
#         energy = rand(abmrng(model), 1:(Δenergy_wolf*2)) - 1
#         add_agent!(RLWolf, model, energy, wolf_reproduce, Δenergy_wolf)
#     end
# 
#     # Initialize grass with random growth states
#     for p in positions(model)
#         fully_grown = rand(abmrng(model), Bool)
#         countdown = fully_grown ? regrowth_time : rand(abmrng(model), 1:regrowth_time) - 1
#         model.countdown[p...] = countdown
#         model.fully_grown[p...] = fully_grown
#     end
# 
#     return model
# end
# 
# # Initialize model function for RL ABM
# function initialize_rl_model(; n_sheeps=30, n_wolves=5, dims=(10, 10), regrowth_time=10,
#     Δenergy_sheep=5, Δenergy_wolf=20, sheep_reproduce=0.2, wolf_reproduce=0.05,
#     observation_radius=4, seed=1234)
# 
#     # RL configuration specifying learning environment parameters
#     rl_config = RLConfig(; 
#         model_init_fn = () -> create_fresh_wolfsheep_model(n_sheeps, n_wolves, dims, regrowth_time,
#             Δenergy_sheep, Δenergy_wolf, sheep_reproduce, wolf_reproduce, seed),
#         observation_fn = wolfsheep_get_observation,
#         reward_fn = wolfsheep_calculate_reward,
#         terminal_fn = wolfsheep_is_terminal_rl,
#         agent_step_fn = wolfsheep_rl_step!,
#         action_spaces = Dict(
#             RLSheep => Crux.DiscreteSpace(5),  # 5 movement actions
#             RLWolf => Crux.DiscreteSpace(5)    # 5 movement actions
#         ),
#         observation_spaces = Dict(
#             RLSheep => Crux.ContinuousSpace((((2 * observation_radius + 1)^2 * 3) + 4,), Float32),
#             RLWolf => Crux.ContinuousSpace((((2 * observation_radius + 1)^2 * 3) + 4,), Float32)
#         ),
#         training_agent_types = [RLSheep, RLWolf],
#         max_steps = 300,
#         observation_radius = observation_radius,
#         discount_rates = Dict(
#             RLSheep => 0.99,  # Long-term planning for survival
#             RLWolf => 0.99    # Long-term planning for hunting
#         )
#     )
# 
#     # Create the model and set RL configuration
#     model = create_fresh_wolfsheep_model(n_sheeps, n_wolves, dims, regrowth_time, Δenergy_sheep,
#         Δenergy_wolf, sheep_reproduce, wolf_reproduce, seed)
# 
#     set_rl_config!(model, rl_config)
# 
#     return model
# end
# ```

# ## Training the RL agents

# Now we create the model and train both sheep and wolves simultaneously.
# This creates a co-evolutionary dynamic where both species adapt to each other.

# ```julia
# # Create the model
# rl_model = initialize_rl_model(n_sheeps=50, n_wolves=10, dims=(20, 20), regrowth_time=30,
#     Δenergy_sheep=4, Δenergy_wolf=20, sheep_reproduce=0.04, wolf_reproduce=0.05, seed=1234)
# 
# println("Created ReinforcementLearningABM with $(nagents(rl_model)) agents")
# println("Sheep: $(length([a for a in allagents(rl_model) if a isa RLSheep]))")
# println("Wolves: $(length([a for a in allagents(rl_model) if a isa RLWolf]))")
# ```

# Train both species simultaneously
# ```julia
# println("\nTraining wolves and sheep with reinforcement learning...")
# try
#     train_model!(rl_model,:simultaneous;  # Both species learn at the same time
#         n_iterations=5,
#         batch_size=400 * nagents(rl_model),
#         solver_params=Dict(
#             :ΔN => 100 * nagents(rl_model),
#             :log => (period=100 * nagents(rl_model),),
#             :max_steps => 200 * nagents(rl_model)
#         ))
#     println("Training completed successfully")
# catch e
#     println("Training failed with error: $e")
#     rethrow(e)
# end
# ```


# ## Running the trained model

# After training, we create a fresh model instance and apply the learned policies
# to observe how the trained agents behave in the predator-prey ecosystem.

# ```julia
# # Create a fresh model instance for simulation
# println("\nCreating fresh Wolf-Sheep model for simulation...")
# fresh_ws_model = initialize_rl_model(n_sheeps=50, n_wolves=10, dims=(20, 20), regrowth_time=30,
#     Δenergy_sheep=4, Δenergy_wolf=20, sheep_reproduce=0.04, wolf_reproduce=0.05, seed=1234)
# 
# # Copy the trained policies to the fresh model
# copy_trained_policies!(fresh_ws_model, rl_model)
# println("Applied trained policies to fresh model")
# ```

# ## Visualization

# Let's visualize the ecosystem and observe the learned behaviors.

# ```julia
# using CairoMakie, ColorSchemes
# CairoMakie.activate!()
# 
# # Define colors and markers for different agent types
# function agent_color(agent)
#     if agent isa RLSheep
#         return :lightblue  # Sheep are light blue
#     elseif agent isa RLWolf
#         return :red        # Wolves are red
#     else
#         return :black      # Fallback color
#     end
# end
# 
# function agent_marker(agent)
#     if agent isa RLSheep
#         return :circle     # Sheep are circles
#     elseif agent isa RLWolf
#         return :rect       # Wolves are squares
#     else
#         return :circle     # Fallback marker
#     end
# end
# 
# # Plot the initial state
# fig, ax = abmplot(fresh_ws_model;
#     agent_color=agent_color,
#     agent_marker=agent_marker
# )
# display(fig)
# ```

# Run simulation with trained agents
# ```julia
# println("\nRunning simulation with trained RL agents...")
# initial_sheep = length([a for a in allagents(fresh_ws_model) if a isa RLSheep])
# initial_wolves = length([a for a in allagents(fresh_ws_model) if a isa RLWolf])
# println("Initial populations - Sheep: $initial_sheep, Wolves: $initial_wolves")
# 
# # Step the model forward to observe trained behavior
# try
#     Agents.step!(fresh_ws_model, 200)
#     println("Simulation completed successfully")
# catch e
#     println("Simulation failed with error: $e")
#     rethrow(e)
# end
# 
# # Check final population numbers
# final_sheep = length([a for a in allagents(fresh_ws_model) if a isa RLSheep])
# final_wolves = length([a for a in allagents(fresh_ws_model) if a isa RLWolf])
# 
# println("Population changes after 200 steps:")
# println("Sheep: $initial_sheep → $final_sheep")
# println("Wolves: $initial_wolves → $final_wolves")
# 
# # Analyze the results
# if final_sheep > 0 && final_wolves > 0
#     println("Success! Both species coexist - predator-prey balance maintained")
# elseif final_sheep == 0
#     println("Wolves were too successful - sheep went extinct")
# elseif final_wolves == 0
#     println("Sheep outlasted wolves - predators died out")
# end
# ```

# ## Creating an animation

# Create a video showing the trained ecosystem dynamics over time.
# ```julia
# fresh_ws_model = initialize_rl_model(n_sheeps=50, n_wolves=10, dims=(20, 20), regrowth_time=30,
#     Δenergy_sheep=4, Δenergy_wolf=20, sheep_reproduce=0.04, wolf_reproduce=0.05, seed=1234)
# 
# # Copy the trained policies to the fresh model
# copy_trained_policies!(fresh_ws_model, rl_model)
# 
# plotkwargs = (
#     agent_color=agent_color,
#     agent_marker=agent_marker,
# )
# abmvideo("wolfsheep_rl.mp4", fresh_ws_model; frames=100,
#     framerate=2,
#     title="Wolf-Sheep Model with RL - Blue=Sheep, Red=Wolves",
#     plotkwargs...)
# ```


# ## Key takeaways

# This example demonstrates several important concepts:

# 1. **Multi-agent RL**: Both predator and prey species learn simultaneously,
#    creating co-evolutionary dynamics where each species adapts to the other.

# 2. **Complex reward structures**: Different reward functions for different agent types
#    (survival for sheep, hunting for wolves) lead to emergent ecological behaviors.

# 3. **Spatial awareness**: Agents learn to use local environmental information
#    (locations of prey/predators, grass availability) to make strategic decisions.

# 4. **Emergent strategies**: Trained agents may develop sophisticated behaviors like
#    flocking (sheep), pursuit strategies (wolves), or territorial behaviors.

# 5. **Ecosystem dynamics**: The learned behaviors can lead to more realistic
#    predator-prey cycles compared to purely random movement models.

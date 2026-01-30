# # [Boltzmann Wealth Model with Reinforcement Learning](@id rltutorial)

# ```@raw html
# <video width="auto" controls autoplay loop>
# <source src="../rn_boltzmann.mp4" type="video/mp4">
# </video>
# ```

# ```@raw html
# <video width="auto" controls autoplay loop>
# <source src="../rl_boltzmann.mp4" type="video/mp4">
# </video>
# ```

# This is a tutorial for the [`ReinforcementLearningABM`](@ref) model which
# combines reinforcement learning with agent based modelling.
# The example demonstrates how to integrate reinforcement learning with
# agent based modelling using the Boltzmann wealth distribution model. In this model,
# agents move around a grid and exchange wealth when they encounter other agents,
# but their movement decisions are learned through reinforcement learning rather
# than being random.

# The model showcases how RL agents can learn to optimize their behavior to achieve
# specific goals - in this case, reducing wealth inequality as measured by the
# Gini coefficient.

# !!! note "`Crux` needed!"
#
#     This functionality is formally a package extension. To access it you need to be `using Crux`.

# !!! note "Reinforcement Learning fundamentals assummed"
#
#     The discussion in this tutorial assumes you are familiar with the fundamentals of
#     reinforcement learning. If not, you can start your journey from the
#     [Wikipedia page](https://en.wikipedia.org/wiki/Reinforcement_learning).


# ## Model specification

# The Boltzmann wealth model is a classic example in econophysics where agents
# represent economic actors who exchange wealth. The traditional model uses random
# movement, but here we replace that with learned behavior using reinforcement learning.

# **Rules:**
# - Agents move on a 2D periodic grid
# - When agents occupy the same position, they may exchange wealth
# - Wealth flows from richer to poorer agents
# - Agent movement is learned through RL to minimize wealth inequality

# **RL Integration:**
# - **Actions**: Stay, move North, South, East, or West (5 discrete actions)
# - **Observations**: Local neighborhood information and agent's relative wealth
# - **Reward**: Reduction in Gini coefficient (wealth inequality measure)
# - **Goal**: Learn movement patterns that promote wealth redistribution

# ## Loading packages and defining the agent type

# This part is the same as with the normal usage of Agents.jl

using Agents, Random, Statistics, Distributions

# while we also need to import the library required for the RL extension
using Crux

# and define the agent type as usual

@agent struct RLBoltzmannAgent(GridAgent{2})
    wealth::Int
end

# ## Utility functions

# First, we define the Gini coefficient calculation, which measures wealth inequality.
# A Gini coefficient of 0 represents perfect equality, while 1 represents maximum inequality.

function gini(model::ABM)
    wealths = [a.wealth for a in allagents(model)]
    n, sum_wi = length(wealths), sum(wealths)
    (n <= 1 || sum_wi == 0.0) && return 0.0
    num = sum((2i - n - 1) * w for (i, w) in enumerate(sort!(wealths)))
    den = n * sum_wi
    return num / den
end

# ## Agent stepping function

# The agent stepping function defines how agents behave in response to RL actions.
# Unlike traditional ABM where this might contain random movement, here the movement
# is determined by the RL policy based on the chosen action.

# This function augments the standard Agents.jl `agent_step!` signature by including
# an additional third argument `action::Int` that represents the action chosen
# by the RL policy. This action is optimized during training by the RL framework.
# The correspondence between integers and "actual agent actions" is decided by the user.

function boltzmann_rl_step!(agent::RLBoltzmannAgent, model, action::Int)
    ## Action definitions: 1=stay, 2=north, 3=south, 4=east, 5=west
    dirs = ((0, 0), (0, 1), (0, -1), (1, 0), (-1, 0))
    walk!(agent, dirs[action], model; ifempty=false)

    ## Wealth exchange mechanism
    other = random_agent_in_position(agent.pos, model, a -> a.id != agent.id)
    if !isnothing(other)
        ## Transfer wealth from richer to poorer agent
        if other.wealth > agent.wealth && other.wealth > 0
            agent.wealth += 1
            other.wealth -= 1
        end
    end
end


# ## RL-specific functions

# The following functions define how the RL environment interacts with the ABM:
# - **Observation function**: Extracts relevant state information for the RL agent
# - **Reward function**: Defines what behavior we want to encourage
# - **Terminal function**: Determines when an episode ends

# ### Observation function

# The observation function is a key component of reinforcement learning.
# In our scenario, it focuses on the local neighborhood of the agent and the
# wealth distribution in this neighborhood (as well as the agent's own wealth).
# Note that the observation function must return the observed quantities as a `Vector{Float32}`.

function global_to_local(neighbor_pos, center_pos, radius, grid_dims) # helper function
    function transform_dim(neighbor_coord, center_coord, dim_size)
        local_center = radius + 1
        delta = neighbor_coord - center_coord
        delta > radius && return local_center + (delta - dim_size)
        delta < -radius && return local_center + (delta + dim_size)
        return local_center + delta
    end
    return ntuple(i -> transform_dim(neighbor_pos[i], center_pos[i], grid_dims[i]), length(grid_dims))
end

function boltzmann_get_observation(agent, model::ABM)
    width, height = spacesize(model)
    observation_radius = model.observation_radius

    grid_size = 2 * observation_radius + 1
    ## 2 channels: occupancy and relative wealth
    neighborhood_grid = zeros(Float32, grid_size, grid_size, 2)

    for pos in nearby_positions(agent.pos, model, observation_radius)
        k = 0
        for neighbor in agents_in_position(pos, model)
            lpos = global_to_local(pos, agent.pos, observation_radius, spacesize(model))
            neighbor.id == agent.id && continue
            neighborhood_grid[lpos..., 1] = 1.0
            wealth_diff = Float32(neighbor.wealth - agent.wealth)
            wealth_sum = Float32(neighbor.wealth + agent.wealth)
            if wealth_sum > 0
                k += 1
                neighborhood_grid[lpos..., 2] = wealth_diff / wealth_sum
            end
            k != 0 && (neighborhood_grid[lpos..., 2] /= k)
        end
    end

    total_wealth = sum(a.wealth for a in allagents(model))
    normalized_wealth = total_wealth > 0 ? Float32(agent.wealth / total_wealth) : 0.0f0
    normalized_pos_x = Float32(agent.pos[1] / width)
    normalized_pos_y = Float32(agent.pos[2] / height)

    return vcat(
        normalized_wealth,
        normalized_pos_x,
        normalized_pos_y,
        vec(neighborhood_grid)
    )
end

# ### Reward function

# The reward function is also a key component of reinforcement learning.
# Here, the reward function encourages agents to reduce wealth inequality by rewarding
# decreases in the Gini coefficient. This creates an incentive for agents to learn
# movement patterns that promote wealth redistribution.
# As the Gini coefficient is only dependent on the global model state,
# all agents have the same reward, and hence the reward function does not
# actually utilize the input agent.

function boltzmann_calculate_reward(agent, action, previous_model, current_model)

    initial_gini = gini(previous_model)
    final_gini = gini(current_model)

    ## Reward decrease in Gini coefficient
    reward = (initial_gini - final_gini) * 100
    reward > 0 && (reward = reward / (abmtime(current_model) + 1))
    ## Small penalty for neutral actions
    reward <= 0.0 && (reward = -0.1f0)

    return reward
end

# ### Terminal condition

# Define when an RL episode should end. Here, episodes terminate when wealth
# inequality (Gini coefficient) drops below a threshold, indicating success.

boltzmann_is_terminal_rl(env) = gini(env) < 0.1

# ## Model initialization

# The following functions handle model creation and RL configuration setup.
# We first create a separate function the generates a [`ReinforcementLearningABM`](@ref)
# without an RL configuration. This function will be further used during training to
# generate new models while updating the overall model policies.

function create_fresh_boltzmann_model(num_agents, dims, initial_wealth, observation_radius, seed=rand(Int))
    rng = MersenneTwister(seed)
    space = GridSpace(dims; periodic=true)

    properties = Dict{Symbol,Any}(:observation_radius => observation_radius)

    model = ReinforcementLearningABM(RLBoltzmannAgent, space;
        agent_step=boltzmann_rl_step!,
        properties=properties, rng=rng, scheduler=Schedulers.Randomly()
    )

    ## Add agents with random initial wealth
    for _ in 1:num_agents
        add_agent_single!(RLBoltzmannAgent, model, rand(rng, 1:initial_wealth))
    end

    return model
end

# We then use this function to create another keyword-based function,
# which initializes an RL model with the RL training functions we have created so far:

function initialize_boltzmann_rl_model(; num_agents=10, dims=(10, 10), initial_wealth=10, observation_radius=4)
    ## Create the main model using the initialization function
    model = create_fresh_boltzmann_model(num_agents, dims, initial_wealth, observation_radius)

    ## `RLConfig` specifies the learning environment parameters
    rl_config = RLConfig(;
        model_init_fn = () -> create_fresh_boltzmann_model(num_agents, dims, initial_wealth, observation_radius),
        observation_fn = boltzmann_get_observation,
        reward_fn = boltzmann_calculate_reward,
        terminal_fn = boltzmann_is_terminal_rl,
        agent_step_fn = boltzmann_rl_step!,
        action_spaces = Dict(
            RLBoltzmannAgent => Crux.DiscreteSpace(5)  ## 5 possible actions
        ),
        observation_spaces = Dict(
            ## Observation space: (2*radius+1)² grid cells * 2 channels + 3 agent features
            RLBoltzmannAgent => Crux.ContinuousSpace((((2 * observation_radius + 1)^2 * 2) + 3,), Float32)
        ),
        training_agent_types = [RLBoltzmannAgent]
    )

    ## Set the RL configuration to the model
    set_rl_config!(model, rl_config)

    return model
end

# ## Training the RL agents

# Now we create and train our model. The agents will learn through trial and error
# which movement patterns best achieve the goal of reducing wealth inequality.

# Create and train the Boltzmann RL model
boltzmann_rl_model = initialize_boltzmann_rl_model()

# Train the Boltzmann agents
train_model!(
    boltzmann_rl_model;
    training_steps=200000,
    max_steps=50,
    solver_params=Dict(
        :ΔN => 200,            # Custom batch size for PPO updates
        :log => (period=1000,) # Log every 1000 steps
    ))

# Plot the learning curve to see how agents improved over training
plot_learning(boltzmann_rl_model.training_history[RLBoltzmannAgent])

# ## Running the trained model

# After training, we create a fresh model instance and apply the learned policies
# to see how well the agents perform.

# First, create a fresh model instance for simulation with the same parameters
fresh_boltzmann_model = initialize_boltzmann_rl_model()

# And copy the trained policies to the fresh model
copy_trained_policies!(fresh_boltzmann_model, boltzmann_rl_model)

# Let's visualize the initial state and run a simulation to see the trained behavior.
using CairoMakie
using CairoMakie.Makie.ColorSchemes

function agent_color(agent) # Custom color function based on wealth
    max_expected_wealth = 10
    clamped_wealth = clamp(agent.wealth, 0, max_expected_wealth)
    normalized_wealth = clamped_wealth / max_expected_wealth
    ## Color scheme: red (poor) to green (rich)
    return ColorSchemes.RdYlGn_4[normalized_wealth]
end
function agent_size(agent) # Custom size function based on wealth
    max_expected_wealth = 10
    clamped_wealth = clamp(agent.wealth, 0, max_expected_wealth)
    size_factor = clamped_wealth / max_expected_wealth
    return 10 + size_factor * 15
end

fig, ax = abmplot(fresh_boltzmann_model;
    agent_color=agent_color,
    agent_size=agent_size,
    agent_marker=:circle
)
ax.title = "Boltzmann Wealth Distribution (Initial State)"
ax.xlabel = "X Position"
ax.ylabel = "Y Position"
fig

# Run simulation with trained agents on the fresh model
initial_gini = gini(fresh_boltzmann_model)
"Initial Gini coefficient: $initial_gini"

# Step the model forward to see the trained behavior
Agents.step!(fresh_boltzmann_model, 10)

# Check the results after simulation
final_gini = gini(fresh_boltzmann_model)
"Final Gini coefficient: $final_gini"

# Plot the final state
fig, ax = abmplot(fresh_boltzmann_model;
    agent_color=agent_color,
    agent_size=agent_size,
    agent_marker=:circle
)
ax.title = "Boltzmann Wealth Distribution (After 10 RL Steps)"
ax.xlabel = "X Position"
ax.ylabel = "Y Position"
fig

# Finally, let's create a video showing the trained agents in action over multiple steps
# on a bigger scale, and compare visually with a random policy

# Random policy because no policy is specified
fresh_boltzmann_model = initialize_boltzmann_rl_model(; num_agents=500, dims=(100, 100))
plotkwargs = (;
    agent_color=agent_color,
    agent_size=agent_size,
    agent_marker=:circle
)
abmvideo("rn_boltzmann.mp4", fresh_boltzmann_model; frames=100,
    framerate=20,
    title="Boltzmann Wealth Model with Random Agents",
    plotkwargs...
)

# We know copy the trained policies and the agents are...smarter!
fresh_boltzmann_model = initialize_boltzmann_rl_model(; num_agents=500, dims=(100, 100))
copy_trained_policies!(fresh_boltzmann_model, boltzmann_rl_model)
abmvideo("rl_boltzmann.mp4", fresh_boltzmann_model; frames=100,
    framerate=20,
    title="Boltzmann Wealth Model with RL Agents",
    plotkwargs...
)

# ## Key takeaways

# This example demonstrated several important concepts:

# 1. **RL-ABM Integration**: How to integrate reinforcement learning
#    with agent-based modeling using the [`ReinforcementLearningABM`] type.

# 2. **Custom Reward Design**: The reward function encourages behavior that
#    reduces wealth inequality, showing how RL can optimize for specific outcomes.

# 3. **Observation Engineering**: Agents observe their local neighborhood, providing them with relevant information for decision-making.

# 4. **Policy Transfer**: Trained policies can be copied to fresh model instances,
#    enabling evaluation and deployment of learned behaviors.


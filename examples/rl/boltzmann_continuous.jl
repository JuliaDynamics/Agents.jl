using Agents, Random, CairoMakie, POMDPs, Crux, Flux, Distributions

## 1. Agent Definition 
@agent struct BoltzmannAgent(GridAgent{2})
    wealth::Int
end


## 2. Gini Coefficient Calculation Function
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

## 3. Agent Step Function
function boltz_step!(agent::BoltzmannAgent, model::ABM, action::Int)
    # Action definitions:
    # 1: Stay
    # 2: North (+y)
    # 3: South (-y)
    # 4: East  (+x)
    # 5: West  (-x)

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
        other = rand(getfield(model, :rng), others)
        if other.wealth > agent.wealth && other.wealth > 0
            # Transfer wealth from other to agent
            agent.wealth += 1
            other.wealth -= 1
        end
    end
end

## 4. Represent the state of the environment
struct BoltzmannState
    agent_wealths::Vector{Int}
    agent_positions::Vector{NTuple{2,Int}}
    step_count::Int
    current_gini::Float64
end

# Helper to convert model to BoltzmannState
function model_to_state(model::ABM, step_count::Int)
    sorted_agents = sort(collect(allagents(model)); by=a -> a.id)
    wealths = [a.wealth for a in sorted_agents]
    positions = [a.pos for a in sorted_agents]
    current_gini = gini(wealths)
    return BoltzmannState(wealths, positions, step_count, current_gini)
end

# Convert state to vector
function state_to_vector(s::BoltzmannState)::Vector{Float32}
    N_AGENTS = length(s.agent_wealths)
    state_vec = Vector{Float32}(undef, N_AGENTS * 3 + 2)

    # Interleave agent data: wealth1, x1, y1, wealth2, x2, y2, ...
    for i in 1:N_AGENTS
        idx = 3 * (i - 1) + 1
        state_vec[idx] = Float32(s.agent_wealths[i])
        state_vec[idx+1] = Float32(s.agent_positions[i][1])  # x
        state_vec[idx+2] = Float32(s.agent_positions[i][2])  # y
    end

    # Add global info at the end
    state_vec[3*N_AGENTS+1] = Float32(s.step_count)
    state_vec[3*N_AGENTS+2] = Float32(s.current_gini)

    return state_vec
end

## 5. Custom MDP - Treating as single agent controlling all
mutable struct BoltzmannEnv <: POMDP{Vector{Float32},Vector{Int},Vector{Float32}}
    abm_model::ABM
    num_agents::Int
    dims::Tuple{Int,Int}
    initial_wealth::Int
    max_steps::Int
    gini_threshold::Float64
    rng::AbstractRNG
end

# Constructor for BoltzmannEnv 
function BoltzmannEnv(; num_agents=50, dims=(10, 10), seed=123, initial_wealth=1, max_steps=200, gini_threshold=0.1)
    rng = MersenneTwister(seed)
    env = BoltzmannEnv(
        boltzmann_money_model_rl_init(num_agents=num_agents, dims=dims, seed=seed, initial_wealth=initial_wealth),
        num_agents,
        dims,
        initial_wealth,
        max_steps,
        gini_threshold,
        rng
    )
    return env
end

# A function to initialize the ABM specifically for the RL environment
function boltzmann_money_model_rl_init(; num_agents=100, dims=(10, 10), seed=1234, initial_wealth=10)
    space = GridSpace(dims; periodic=true)
    rng = MersenneTwister(seed)
    properties = Dict{Symbol,Any}(
        :gini_coefficient => 0.0,
        :step_count => 0
    )
    model = StandardABM(BoltzmannAgent, space;
        (model_step!)=boltz_model_step!,
        rng,
        properties=properties
    )

    for _ in 1:num_agents
        add_agent_single!(BoltzmannAgent, model, rand(rng, 1:initial_wealth))
    end
    wealths = [a.wealth for a in allagents(model)]
    model.gini_coefficient = gini(wealths)
    return model
end

# Model Step Function 
function boltz_model_step!(model::ABM)
    wealths = [agent.wealth for agent in allagents(model)]
    model.gini_coefficient = gini(wealths)
    model.step_count += 1
end

## 6. Implement POMDPs.jl Interface for BoltzmannEnv
const NUM_INDIVIDUAL_ACTIONS = 5 # Stay, N, S, E, W

# Action space: vector of actions for each agent
function POMDPs.actions(env::BoltzmannEnv)
    # Return all possible combinations as vectors of length num_agents
    # Each element can be 1-5 (the 5 possible actions)
    return [collect(a) for a in Iterators.product(fill(1:NUM_INDIVIDUAL_ACTIONS, env.num_agents)...)]
end

function POMDPs.observation(env::BoltzmannEnv, s::Vector{Float32})
    # s is the full, unnormalized state vector from state_to_vector
    n_agents = env.num_agents

    # Determine normalization parameters from the environment
    max_possible_wealth = Float32(env.initial_wealth * env.num_agents) # Total wealth is conserved
    min_possible_wealth = Float32(0) # Wealth can go to 0

    max_x = Float32(env.dims[1])
    min_x = Float32(1) # GridSpace is 1-indexed
    max_y = Float32(env.dims[2])
    min_y = Float32(1)

    normalized_obs = Vector{Float32}(undef, n_agents * 3) # Observation excludes step_count and Gini

    for i in 1:n_agents
        idx = 3 * (i - 1) + 1

        # Normalize wealth
        normalized_obs[idx] = (s[idx] - min_possible_wealth) / (max_possible_wealth - min_possible_wealth)

        # Normalize x position
        normalized_obs[idx+1] = (s[idx+1] - min_x) / (max_x - min_x)

        # Normalize y position
        normalized_obs[idx+2] = (s[idx+2] - min_y) / (max_y - min_y)
    end
    return normalized_obs
end


# Define the initial state of the MDP
function POMDPs.initialstate(env::BoltzmannEnv)
    env.abm_model = boltzmann_money_model_rl_init(
        num_agents=env.num_agents,
        dims=env.dims,
        seed=1234,
        initial_wealth=env.initial_wealth
    )
    return Dirac(state_to_vector(model_to_state(env.abm_model, 0)))
end

function POMDPs.initialobs(env::BoltzmannEnv, initial_state)
    obs = POMDPs.observation(env, initial_state)
    return Dirac(obs)
end

# Define the transition function
function POMDPs.transition(env::BoltzmannEnv, s, a::Vector{Int})
    agents_by_id = sort(collect(allagents(env.abm_model)), by=x -> x.id) # Ensure consistent order

    for (i, agent) in enumerate(agents_by_id)
        boltz_step!(agent, env.abm_model, a[i])
    end

    # Run the model step (updates Gini coefficient, increments step_count)
    boltz_model_step!(env.abm_model)

    # Return the new state
    next_state = state_to_vector(model_to_state(env.abm_model, env.abm_model.step_count))
    return next_state
end

function POMDPs.gen(env::BoltzmannEnv, state, action::Vector{Int}, rng::AbstractRNG)
    next_state = POMDPs.transition(env, state, action)
    obs = POMDPs.observation(env, next_state)
    r = POMDPs.reward(env, state, action, next_state)
    return (sp=next_state, o=obs, r=r)
end

# Define the reward function 
function POMDPs.reward(env::BoltzmannEnv, s, a::Vector{Int}, sp)
    reward = 0.0
    new_gini = sp[end] # Last element is the Gini coefficient
    prev_gini = s[end] # Last element of the previous state

    if new_gini < prev_gini
        reward = (prev_gini - new_gini) * 20.0
    else
        reward = -0.05
    end

    if POMDPs.isterminal(env, sp)
        if sp[end] < env.gini_threshold
            reward += 50.0 / (sp[end-1] + 1e-6)
        elseif sp[end-1] >= env.max_steps
            reward -= 1.0
        end
    end
    return reward
end

# Define terminal states
function POMDPs.isterminal(env::BoltzmannEnv, s)
    s[end] < env.gini_threshold || s[end-1] >= env.max_steps
end


Crux.state_space(env::BoltzmannEnv) = Crux.ContinuousSpace((env.num_agents * 3 + 2,))
POMDPs.observations(env::BoltzmannEnv) = Crux.ContinuousSpace((env.num_agents * 3,)) # Exclude step count and Gini from observations
POMDPs.discount(env::BoltzmannEnv) = 0.99

# Setup the environment
N_AGENTS = 3
env_mdp = BoltzmannEnv(num_agents=N_AGENTS, dims=(10, 10), initial_wealth=10, max_steps=50)

S = Crux.state_space(env_mdp)

function continuous_to_discrete_actions(continuous_actions::Vector{Float32}, num_agents::Int)
    discrete_actions = Vector{Int}(undef, num_agents)
    for i in 1:num_agents
        # continuous_actions[i] is in [-1, 1] from tanh activation
        # Scale to [1.0, NUM_INDIVIDUAL_ACTIONS + 0.999...] for rounding to nearest integer 1-NUM_INDIVIDUAL_ACTIONS
        scaled_val = (continuous_actions[i] + 1.0) / 2.0 * (NUM_INDIVIDUAL_ACTIONS - 1) + 1.0
        action_idx = Int(clamp(round(scaled_val), 1, NUM_INDIVIDUAL_ACTIONS))
        discrete_actions[i] = action_idx
    end
    return discrete_actions
end

# Wrapper environment that converts between continuous and discrete actions
mutable struct ContinuousBoltzmannEnv <: POMDP{Vector{Float32},Vector{Float32},Vector{Float32}}
    discrete_env::BoltzmannEnv
end

function POMDPs.actions(env::ContinuousBoltzmannEnv)
    Crux.ContinuousSpace((1,), Float32)
end

function POMDPs.initialstate(env::ContinuousBoltzmannEnv)
    return POMDPs.initialstate(env.discrete_env)
end

function POMDPs.initialobs(env::ContinuousBoltzmannEnv, initial_state)
    return POMDPs.initialobs(env.discrete_env, initial_state)
end

function POMDPs.observation(env::ContinuousBoltzmannEnv, s::Vector{Float32})
    return POMDPs.observation(env.discrete_env, s)
end

function POMDPs.transition(env::ContinuousBoltzmannEnv, s, a::Vector{Float32})
    discrete_actions = continuous_to_discrete_actions(a, env.discrete_env.num_agents)
    return POMDPs.transition(env.discrete_env, s, discrete_actions)
end

function POMDPs.reward(env::ContinuousBoltzmannEnv, s, a::Vector{Float32}, sp)
    discrete_actions = continuous_to_discrete_actions(a, env.discrete_env.num_agents)
    return POMDPs.reward(env.discrete_env, s, discrete_actions, sp)
end

function POMDPs.isterminal(env::ContinuousBoltzmannEnv, s)
    return POMDPs.isterminal(env.discrete_env, s)
end

function POMDPs.gen(env::ContinuousBoltzmannEnv, state, action::Vector{Float32}, rng::AbstractRNG)
    discrete_actions = continuous_to_discrete_actions(action, env.discrete_env.num_agents)
    return POMDPs.gen(env.discrete_env, state, discrete_actions, rng)
end

Crux.state_space(env::ContinuousBoltzmannEnv) = Crux.state_space(env.discrete_env)
POMDPs.observations(env::ContinuousBoltzmannEnv) = POMDPs.observations(env.discrete_env)
Crux.action_space(env::ContinuousBoltzmannEnv) = Crux.ContinuousSpace((env.discrete_env.num_agents,))
POMDPs.discount(env::ContinuousBoltzmannEnv) = POMDPs.discount(env.discrete_env)

# Create the continuous wrapper
continuous_env = ContinuousBoltzmannEnv(env_mdp)

O = POMDPs.observations(continuous_env)
O.dims

# PPO with continuous actions
V() = ContinuousNetwork(Chain(Dense(Crux.dim(O)..., 128, relu), Dense(128, 64, relu), Dense(64, 1)))
SG() = GaussianPolicy(ContinuousNetwork(Chain(Dense(Crux.dim(O)..., 128, relu), Dense(128, 128, relu), Dense(128, N_AGENTS, tanh))), zeros(Float32, N_AGENTS))

𝒮_ppo = PPO(π=ActorCritic(SG(), V()), S=O, N=200_000, ΔN=4096)
@time π_ppo = solve(𝒮_ppo, continuous_env)
plot_learning(𝒮_ppo)

function run_policy_in_abm(π, env::BoltzmannEnv; max_steps=100)
    # Initialize the ABM from the env
    abm = boltzmann_money_model_rl_init(
        num_agents=env.num_agents,
        dims=env.dims,
        seed=1234,
        initial_wealth=env.initial_wealth
    )

    # Run the simulation
    for step in 1:max_steps
        state_vec = state_to_vector(model_to_state(abm, step))
        a_continuous = action(π, state_vec)
        a_discrete = continuous_to_discrete_actions(a_continuous, env.num_agents)

        agents_by_id = sort(collect(allagents(abm)), by=a -> a.id)

        for (i, agent) in enumerate(agents_by_id)
            boltz_step!(agent, abm, a_discrete[i])
        end

        boltz_model_step!(abm)

        println("Step $step | Gini: ", abm.gini_coefficient)

        if abm.gini_coefficient < env.gini_threshold
            println("Reached Gini threshold.")
            break
        end
    end

    return abm
end

# Run trained policy in a fresh ABM instance
final_abm = run_policy_in_abm(π_ppo, env_mdp; max_steps=100)


export ReinforcementLearningABM
export get_trained_policies, set_rl_config!, copy_trained_policies!
export get_current_training_agent_type, get_current_training_agent, reset_model_for_episode!
export train_model!, setup_rl_training, train_agent_sequential, train_agent_simultaneous
export create_value_network, create_policy_network, create_custom_solver, process_solver_params
export rl_agent_step!, step_ahead_rl!
export has_trained_policy, list_agent_types, list_trained_agent_types, clear_trained_policies!

"""
    ReinforcementLearningABM{S,A,C,T,G,K,F,P,R} <: AgentBasedModel{S}

A concrete implementation of an [`AgentBasedModel`](@ref) that extends [`StandardABM`](@ref)
with built-in reinforcement learning capabilities. This model type integrates RL training
into the ABM framework, allowing agents to learn and adapt their behavior
through interaction with the environment.

## Key Features

- **Integrated RL Training**: Built-in support for training agents using various RL algorithms
- **Multi-Agent Learning**: Support for training multiple agent types simultaneously or sequentially  
- **Flexible Observation Models**: Customizable observation functions for different agent types
- **Reward Engineering**: User-defined reward functions for different learning objectives
- **Policy Management**: Automatic management of trained policies and their deployment

## Structure

The `ReinforcementLearningABM` contains all the components of a `StandardABM` plus additional
RL-specific components:

- `rl_config`: Configuration for RL training including observation functions, reward functions, etc.
- `trained_policies`: Storage for trained policies for each agent type
- `training_history`: Record of training progress and metrics
- `is_training`: Flag indicating whether the model is currently in training mode

## Constructor

```julia
ReinforcementLearningABM(agent_type, space; 
    agent_step!, model_step!, 
    rl_config=nothing,
    kwargs...)
```

Where `rl_config` is a named tuple containing:
- `model_init_fn`: Function to initialize the model for RL training
- `observation_fn`: Function to generate observations for agents
- `observation_to_vector_fn`: Function to convert observations to vectors  
- `reward_fn`: Function to calculate rewards
- `terminal_fn`: Function to check terminal conditions
- `action_spaces`: Dictionary mapping agent types to their action spaces
- `observation_spaces`: Dictionary mapping agent types to their observation spaces
- `training_agent_types`: Vector of agent types that should be trained
- `max_steps`: Maximum steps per episode
- `observation_radius`: Radius for local observations
- `discount_rates`: Dictionary mapping agent types to their discount rates (gamma)

## Usage Example

```julia
# Define agent type
@agent struct MyRLAgent(GridAgent{2})
    energy::Float64
end

# Define RL configuration
config = (
    model_init_fn = my_model_init_function,
    observation_fn = my_observation_function,
    observation_to_vector_fn = my_vector_function,
    reward_fn = my_reward_function,
    terminal_fn = my_terminal_function,
    observation_spaces = Dict(MyRLAgent => Crux.ContinuousSpace((5,), Float32)),
    action_spaces = Dict(MyRLAgent => Crux.DiscreteSpace(4)),
    training_agent_types = [MyRLAgent],
    discount_rates = Dict(MyRLAgent => 0.95)  # Custom discount rate
)

# Create model
model = ReinforcementLearningABM(MyRLAgent, GridSpace((10, 10)); 
                                rl_config=config)

# Train agents
train_model!(model, MyRLAgent; training_steps=10000)

# Run with trained policies
step_rl!(model, 100)
```
"""
struct ReinforcementLearningABM{
    S<:SpaceType,
    A<:AbstractAgent,
    C<:Union{AbstractDict{Int,A},AbstractVector{A}},
    T,G,K,F,P,R<:AbstractRNG} <: AgentBasedModel{S}
    # Standard ABM components
    agents::C
    agent_step::G
    model_step::K
    space::S
    scheduler::F
    properties::P
    rng::R
    agents_types::T
    agents_first::Bool
    maxid::Base.RefValue{Int64}
    time::Base.RefValue{Int64}

    # RL-specific components
    rl_config::Base.RefValue{Any}
    trained_policies::Dict{Type,Any}
    training_history::Dict{Type,Any}
    is_training::Base.RefValue{Bool}
    current_training_agent_type::Base.RefValue{Any}
    current_training_agent_id::Base.RefValue{Int}  # Counter/index for cycling through agents of training type (not actual agent ID)
end

# Extend mandatory internal API for `AgentBasedModel`
containertype(::ReinforcementLearningABM{S,A,C}) where {S,A,C} = C
agenttype(::ReinforcementLearningABM{S,A}) where {S,A} = A
discretimeabm(::ReinforcementLearningABM) = true

# Override property access to handle RL-specific fields
function Base.getproperty(m::ReinforcementLearningABM, s::Symbol)
    # Handle RL-specific fields directly
    if s in (:rl_config, :trained_policies, :training_history, :is_training, :current_training_agent_type, :current_training_agent_id)
        return getfield(m, s)
        # Handle standard ABM fields directly
    elseif s in (:agents, :agent_step, :model_step, :space, :scheduler, :rng,
        :agents_types, :agents_first, :maxid, :time, :properties)
        return getfield(m, s)
    else
        # Delegate to properties for other fields
        p = abmproperties(m)
        if p isa Dict
            return getindex(p, s)
        else # properties is assumed to be a struct
            return getproperty(p, s)
        end
    end
end

function Base.setproperty!(m::ReinforcementLearningABM, s::Symbol, x)
    # Handle RL-specific fields directly
    if s in (:rl_config, :trained_policies, :training_history, :is_training, :current_training_agent_type, :current_training_agent_id)
        return setfield!(m, s, x)
        # Handle standard ABM fields directly (except properties which is immutable)
    elseif s in (:agents, :agent_step, :model_step, :space, :scheduler, :rng,
        :agents_types, :agents_first, :maxid, :time)
        return setfield!(m, s, x)
        # Special handling for properties - can't setfield! but can modify Dict contents
    elseif s == :properties
        error("Cannot replace properties field directly. Use model.properties[key] = value to modify properties.")
    else
        # Delegate to properties for other fields
        properties = abmproperties(m)
        exception = ErrorException(
            "Cannot set property $(s) for model $(nameof(typeof(m))) with " *
            "properties container type $(typeof(properties))."
        )
        properties === nothing && throw(exception)
        if properties isa Dict && haskey(properties, s)
            properties[s] = x
        elseif hasproperty(properties, s)
            setproperty!(properties, s, x)
        else
            throw(exception)
        end
    end
end

"""
    ReinforcementLearningABM(AgentType(s), space [, rl_config]; kwargs...)

Create a `ReinforcementLearningABM` with built-in RL capabilities.

## Arguments

- `AgentType(s)`: The result of `@agent` or `@multiagent` or a `Union` of agent types.
  Any agent type can be used - they don't need to inherit from `RLAgent`.
- `space`: A subtype of `AbstractSpace`. See [Space](@ref available_spaces) for all available spaces.
- `rl_config`: (Optional) A named tuple containing RL configuration. Can be set later with `set_rl_config!`.

## Keyword Arguments

Same as [`StandardABM`](@ref):
- `agent_step!`: Function for stepping agents. If not provided, will use RL-based stepping when policies are available.
- `model_step!`: Function for stepping the model.

## RL Configuration

The `rl_config` should be a named tuple with the following fields:

### Required Functions

- **`observation_fn(model::ReinforcementLearningABM, agent_id::Int, observation_radius::Int) → Any`**  
  Function to generate observations for agents from the model state.
  - `model`: The ReinforcementLearningABM instance
  - `agent_id`: ID of the agent for which to generate observation
  - `observation_radius`: Radius for local neighborhood observations
  - **Returns**: Any structured observation (typically a NamedTuple with agent state and neighborhood info)

- **`observation_to_vector_fn(observation) → Vector{Float32}`**  
  Function to convert structured observations into flat vectors for RL algorithms.
  - `observation`: The structured observation returned by `observation_fn`
  - **Returns**: `Vector{Float32}` - Flattened feature vector for neural network input

- **`reward_fn(env::ReinforcementLearningABM, agent::AbstractAgent, action::Int, initial_model::ReinforcementLearningABM, final_model::ReinforcementLearningABM) → Float32`**  
  Function to calculate scalar rewards based on agent actions and state transitions.
  - `env`: Current model state (typically same as `final_model`)
  - `agent`: The agent that took the action
  - `action`: Integer action that was taken
  - `initial_model`: Model state before the action
  - `final_model`: Model state after the action
  - **Returns**: `Float32` - Scalar reward signal for the action

- **`terminal_fn(env::ReinforcementLearningABM) → Bool`**  
  Function to determine if the current episode should terminate.
  - `env`: The current model state
  - **Returns**: `Bool` - `true` if episode should end, `false` to continue

- **`agent_step_fn(agent::AbstractAgent, model::ReinforcementLearningABM, action::Int) → Nothing`**  
  Function that executes an agent's action in the model.
  - `agent`: The agent taking the action
  - `model`: The model containing the agent
  - `action`: Integer action to execute
  - **Returns**: `Nothing` - Modifies agent and model state in-place

### Required Spaces

- **`action_spaces::Dict{Type, ActionSpace}`**  
  Dictionary mapping agent types to their available actions.
  - Keys: Agent types (e.g., `MyAgent`)
  - Values: Action spaces (e.g., `Crux.DiscreteSpace(5)` for 5 discrete actions)

- **`observation_spaces::Dict{Type, ObservationSpace}`**  
  Dictionary mapping agent types to their observation vector dimensions.
  - Keys: Agent types (e.g., `MyAgent`)  
  - Values: Observation spaces (e.g., `Crux.ContinuousSpace((84,), Float32)` for 84-dim vectors)

### Required Configuration

- **`training_agent_types::Vector{Type}`**  
  Vector of agent types that should undergo RL training.
  - Must be a subset of agent types present in the model
  - Example: `[MyAgent1, MyAgent2]`

- **`max_steps::Int`**  
  Maximum number of simulation steps per training episode.
  - Episodes terminate when this limit is reached OR `terminal_fn` returns `true`
  - Typical values: 50-500 depending on model complexity

- **`observation_radius::Int`**  
  Radius for local neighborhood observations in grid-based models.
  - Used by `observation_fn` to determine neighborhood size
  - Example: `4` creates a 9×9 observation grid around each agent

### Optional Configuration

- **`discount_rates::Dict{Type, Float64}`** *(Optional)*  
  Dictionary mapping agent types to their reward discount factors (γ).
  - Keys: Agent types
  - Values: Discount factors between 0.0 and 1.0
  - **Default**: 0.99 for all agent types if not specified

- **`model_init_fn() → ReinforcementLearningABM`** *(Optional)*  
  Function to create fresh model instances for episode resets during training.
  - **Returns**: New ReinforcementLearningABM instance with reset state
  - If not provided, uses basic model reset without full reinitialization
"""
function ReinforcementLearningABM(
    A::Type,
    space::S=nothing,
    rl_config=nothing;
    agent_step!::G=dummystep,
    model_step!::K=dummystep,
    container::Type=Dict,
    scheduler::F=Schedulers.Randomly(),
    properties::P=nothing,
    rng::R=Random.default_rng(),
    agents_first::Bool=true,
    warn=true,
    kwargs...
) where {S<:SpaceType,G,K,F,P,R<:AbstractRNG}

    # Initialize agent container using proper construction
    agents = construct_agent_container(container, A)
    agents_types = union_types(A)
    T = typeof(agents_types)
    C = typeof(agents)

    model = ReinforcementLearningABM{S,A,C,T,G,K,F,P,R}(
        agents,
        agent_step!,
        model_step!,
        space,
        scheduler,
        properties,
        rng,
        agents_types,
        agents_first,
        Ref(0),
        Ref(0),
        Ref{Any}(rl_config),
        Dict{Type,Any}(),
        Dict{Type,Any}(),
        Ref(false),
        Ref{Any}(nothing),
        Ref(1)
    )

    return model
end

"""
    set_rl_config!(model::ReinforcementLearningABM, config) → ReinforcementLearningABM

Set the RL configuration for the model.

## Arguments
- `model::ReinforcementLearningABM`: The model to configure
- `config`: Named tuple containing RL configuration parameters

## Returns
- `ReinforcementLearningABM`: The configured model (for chaining)

## Example
```julia
config = (
    observation_fn = my_obs_function,
    reward_fn = my_reward_function,
    # ... other config parameters
)
set_rl_config!(model, config)
```
"""
function set_rl_config!(model::ReinforcementLearningABM, config)
    model.rl_config[] = config

    # Initialize training history for each training agent type
    if haskey(config, :training_agent_types)
        for agent_type in config.training_agent_types
            if !haskey(model.training_history, agent_type)
                model.training_history[agent_type] = nothing  # Will be set during training
            end
        end
    end
end

"""
    get_trained_policies(model::ReinforcementLearningABM) → Dict{Type, Any}

Get the dictionary of trained policies for each agent type.

## Arguments
- `model::ReinforcementLearningABM`: The model containing trained policies

## Returns
- `Dict{Type, Any}`: Dictionary mapping agent types to their trained policies

## Example
```julia
policies = get_trained_policies(model)
if haskey(policies, MyAgent)
    println("MyAgent has a trained policy")
end
```
"""
get_trained_policies(model::ReinforcementLearningABM) = model.trained_policies

"""
    copy_trained_policies!(target_model::ReinforcementLearningABM, source_model::ReinforcementLearningABM) → ReinforcementLearningABM

Copy all trained policies from the source model to the target model.

## Arguments
- `target_model::ReinforcementLearningABM`: The model to copy policies to
- `source_model::ReinforcementLearningABM`: The model to copy policies from

## Returns
- `ReinforcementLearningABM`: The target model with copied policies (for chaining)

## Example
```julia
# Train policies in one model
train_model!(training_model, MyAgent)

# Copy to a fresh simulation model
fresh_model = initialize_model()
copy_trained_policies!(fresh_model, training_model)
```
"""
function copy_trained_policies!(target_model::ReinforcementLearningABM, source_model::ReinforcementLearningABM)
    for (agent_type, policy) in source_model.trained_policies
        target_model.trained_policies[agent_type] = policy
    end
    return target_model
end

"""
    step_rl!(model::ReinforcementLearningABM, n::Int=1)

Step the model forward using trained RL policies for agent behavior.
If policies are not available for some agent types, they will use random actions.

Note: This function provides explicit RL stepping. You can also use the standard 
`step!(model, n)` which will automatically use RL policies when available through
the `step_ahead_rl!` infrastructure.
"""
#function step_rl!(model::ReinforcementLearningABM, n::Int=1)
#    if isnothing(model.rl_config[])
#        error("RL configuration not set. Use set_rl_config! first.")
#    end
#
#    for _ in 1:n
#        # Step agents using RL policies
#        for agent in allagents(model)
#            rl_agent_step!(agent, model)
#        end
#
#        # Step the model
#        model.model_step(model)
#
#        # Increment time
#        model.time[] += 1
#    end
#end

"""
    rl_agent_step!(agent, model)

Default agent stepping function for RL agents. This will use trained policies
if available, otherwise fall back to random actions.

## Arguments
- `agent`: The agent to step
- `model::ReinforcementLearningABM`: The model containing the agent

## Notes
This function automatically selects between trained policies and random actions
based on what's available for the agent's type. It's used internally by the
RL stepping infrastructure.

## Example
```julia
agent = model[1]
rl_agent_step!(agent, model)  # Steps the agent using RL policy or random action
```
"""
function rl_agent_step! end

"""
    get_current_training_agent_type(model::ReinforcementLearningABM) → Type
    
Get the currently training agent type.

## Arguments
- `model::ReinforcementLearningABM`: The RL model

## Returns
- `Type`: The agent type currently being trained
"""
function get_current_training_agent_type(model::ReinforcementLearningABM)
    if isnothing(model.rl_config[])
        error("RL configuration not set. Use set_rl_config! first.")
    end

    # Check if current training agent type is set in the model
    if !isnothing(model.current_training_agent_type[])
        return model.current_training_agent_type[]
    end

    # Otherwise, fall back to first agent type in training_agent_types
    config = model.rl_config[]
    if haskey(config, :training_agent_types) && !isempty(config.training_agent_types)
        return config.training_agent_types[1]
    else
        error("No training agent type specified in RL configuration")
    end
end

"""
    get_current_training_agent(model::ReinforcementLearningABM) → Union{AbstractAgent, Nothing}

Get the current agent being trained.

## Arguments
- `model::ReinforcementLearningABM`: The RL model

## Returns
- `Union{AbstractAgent, Nothing}`: The current agent being trained, or `nothing` if no agents of the training type exist

## Notes
The `current_training_agent_id` is a counter/index that cycles through agents of the training type,
not the actual agent ID.

## Example
```julia
agent = get_current_training_agent(model)
if !isnothing(agent)
    println("Training agent ID: $(agent.id)")
end
```
"""
function get_current_training_agent(model::ReinforcementLearningABM)
    current_agent_type = get_current_training_agent_type(model)
    agents_of_type = [a for a in allagents(model) if typeof(a) == current_agent_type]

    if isempty(agents_of_type)
        return nothing
    end

    current_agent_id = model.current_training_agent_id[]

    # Cycle through agents of the training type
    agent_idx = ((current_agent_id - 1) % length(agents_of_type)) + 1
    return agents_of_type[agent_idx]
end

"""
    reset_model_for_episode!(model::ReinforcementLearningABM)

Reset the model to initial state for a new training episode.

## Arguments
- `model::ReinforcementLearningABM`: The model to reset

## Notes
This function resets the model time, agent positions, and other state based on the
`model_init_fn` in the RL configuration. It's used internally during training
to reset episodes.

## Example
```julia
reset_model_for_episode!(model)
println("Model reset to time: $(abmtime(model))")
```
"""
function reset_model_for_episode!(model::ReinforcementLearningABM)
    if isnothing(model.rl_config[])
        error("RL configuration not set. Use set_rl_config! first.")
    end

    #println("DEBUG RESET: Starting model reset")
    # Reset time
    model.time[] = 0

    # Reset current agent ID
    model.current_training_agent_id[] = 1

    config = model.rl_config[]

    # If there's a model initialization function, use it
    if haskey(config, :model_init_fn)
        #println("DEBUG RESET: Using model_init_fn")
        new_model = config.model_init_fn()
        # Copy agents and properties from new model
        remove_all!(model)
        for agent in allagents(new_model)
            add_agent!(agent, model)
        end
        # Copy properties if they exist
        if !isnothing(abmproperties(new_model))
            for (key, value) in pairs(abmproperties(new_model))
                abmproperties(model)[key] = value
            end
        end
    end
end

"""
    step_ahead_rl!(model::ReinforcementLearningABM, agent_step!, model_step!, n, t)

Steps the model forward using RL policies for a specified number of steps.

## Arguments
- `model::ReinforcementLearningABM`: The model to step
- `agent_step!`: Agent stepping function (fallback for non-RL agents)
- `model_step!`: Model stepping function
- `n`: Number of steps or stepping condition
- `t`: Time reference

## Notes
This function is part of the internal stepping infrastructure and automatically
chooses between RL policies and standard agent stepping based on availability.
It's called internally by the `step!` function.
"""
function step_ahead_rl! end

################
### TRAINING ###
################

"""
    setup_rl_training(model::ReinforcementLearningABM, agent_type; 
        training_steps=50_000,
        value_network=nothing,
        policy_network=nothing,
        solver=nothing,
        solver_type=:PPO,
        solver_params=Dict()
    ) → (env, solver)

Set up RL training for a specific agent type using the ReinforcementLearningABM directly.

## Arguments
- `model::ReinforcementLearningABM`: The model to train
- `agent_type::Type`: The agent type to train

## Keyword Arguments  
- `training_steps::Int`: Number of training steps (default: 50_000)
- `value_network`: Custom value network function (default: auto-generated)
- `policy_network`: Custom policy network function (default: auto-generated)
- `solver`: Complete custom solver (default: auto-generated based on solver_type)
- `solver_type::Symbol`: Type of RL solver (:PPO, :DQN, :A2C) (default: :PPO)
- `solver_params::Dict`: Custom parameters for the solver (default: Dict())

## Returns
- `(env, solver)`: A tuple containing the wrapped environment and configured solver

## Example
```julia
env, solver = setup_rl_training(model, MyAgent; 
    training_steps=10000,
    solver_type=:PPO)
policy = solve(solver, env)
```
"""
function setup_rl_training end

"""
    train_agent_sequential(model::ReinforcementLearningABM, agent_types; 
        training_steps=50_000,
        custom_networks=Dict(),
        custom_solvers=Dict(),
        solver_types=Dict(),
        solver_params=Dict()
    ) → (policies, solvers)

Train multiple agent types sequentially using the ReinforcementLearningABM, where each 
subsequent agent is trained against the previously trained agents.

## Arguments
- `model::ReinforcementLearningABM`: The model to train
- `agent_types`: Agent type or vector of agent types to train sequentially

## Keyword Arguments
- `training_steps::Int`: Number of training steps per agent (default: 50_000)
- `custom_networks::Dict`: Dict mapping agent types to custom network configurations
- `custom_solvers::Dict`: Dict mapping agent types to custom solvers
- `solver_types::Dict`: Dict mapping agent types to solver types (default: :PPO for all)
- `solver_params::Dict`: Dict mapping agent types to solver parameters

## Returns
- `(policies, solvers)`: Tuple containing dictionaries of trained policies and solvers by agent type

## Example
```julia
policies, solvers = train_agent_sequential(model, [Agent1, Agent2];
    training_steps=20000,
    solver_types=Dict(Agent1 => :PPO, Agent2 => :DQN))
```
"""
function train_agent_sequential end

"""
    train_agent_simultaneous(model::ReinforcementLearningABM, agent_types; 
        n_iterations=5, 
        batch_size=10_000,
        custom_networks=Dict(),
        custom_solvers=Dict(),
        solver_types=Dict(),
        solver_params=Dict()
    ) → (policies, solvers)

Train multiple agent types simultaneously using the ReinforcementLearningABM with 
alternating batch updates.

## Arguments
- `model::ReinforcementLearningABM`: The model to train
- `agent_types`: Agent type or vector of agent types to train simultaneously

## Keyword Arguments
- `n_iterations::Int`: Number of alternating training iterations (default: 5)
- `batch_size::Int`: Size of training batches for each iteration (default: 10_000)
- `custom_networks::Dict`: Dict mapping agent types to custom network configurations
- `custom_solvers::Dict`: Dict mapping agent types to custom solvers
- `solver_types::Dict`: Dict mapping agent types to solver types (default: :PPO for all)
- `solver_params::Dict`: Dict mapping agent types to solver parameters

## Returns
- `(policies, solvers)`: Tuple containing dictionaries of trained policies and solvers by agent type

## Example
```julia
policies, solvers = train_agent_simultaneous(model, [Agent1, Agent2];
    n_iterations=10,
    batch_size=5000)
```
"""
function train_agent_simultaneous end

## Helper Functions for Custom Neural Networks
"""
    process_solver_params(solver_params, agent_type) → Dict

Process solver parameters that can be either global or per-agent-type.

## Arguments
- `solver_params::Dict`: Dictionary of solver parameters, either global or per-agent-type
- `agent_type::Type`: The agent type to get parameters for

## Returns
- `Dict`: Parameters specific to the given agent type

## Example
```julia
# Global parameters
params = process_solver_params(Dict(:ΔN => 100), MyAgent)  # Returns Dict(:ΔN => 100)

# Per-agent-type parameters  
params = process_solver_params(Dict(Agent1 => Dict(:ΔN => 100)), Agent1)  # Returns Dict(:ΔN => 100)
```
"""
function process_solver_params(solver_params, agent_type)
    if isempty(solver_params)
        return Dict()
    end

    # Check if solver_params contains agent types as keys
    if any(k isa Type for k in keys(solver_params))
        # Per-agent-type parameters
        return get(solver_params, agent_type, Dict())
    else
        # Global parameters
        return solver_params
    end
end

"""
    create_value_network(input_dims, hidden_layers=[64, 64], activation=relu) → Function

Create a custom value network with specified architecture.

## Arguments
- `input_dims`: Tuple specifying the input dimensions
- `hidden_layers::Vector{Int}`: Sizes of hidden layers (default: [64, 64])
- `activation`: Activation function (default: relu)

## Returns
- `Function`: A function that creates a ContinuousNetwork when called

## Example
```julia
value_net = create_value_network((10,), [32, 32])
network = value_net()  # Create the actual network
```
"""
function create_value_network end

"""
    create_policy_network(input_dims, output_dims, action_space, hidden_layers=[64, 64], activation=relu) → Function

Create a custom policy network with specified architecture.

## Arguments
- `input_dims`: Tuple specifying the input dimensions
- `output_dims::Int`: Number of output neurons (action space size)
- `action_space`: The action space for the policy
- `hidden_layers::Vector{Int}`: Sizes of hidden layers (default: [64, 64])
- `activation`: Activation function (default: relu)

## Returns
- `Function`: A function that creates a DiscreteNetwork when called

## Example
```julia
policy_net = create_policy_network((10,), 4, Crux.DiscreteSpace(4), [32, 32])
network = policy_net()  # Create the actual network
```
"""
function create_policy_network end

"""
    create_custom_solver(solver_type, π, S; custom_params...) → Solver

Create a custom solver with specified parameters.

## Arguments
- `solver_type::Symbol`: Type of solver (:PPO, :DQN, :A2C)
- `π`: Policy network
- `S`: State/observation space
- `custom_params...`: Additional parameters for the solver

## Returns
- `Solver`: The configured RL solver

## Example
```julia
solver = create_custom_solver(:PPO, policy, obs_space; N=10000, ΔN=100)
```
"""
function create_custom_solver end

"""
    train_model!(model::ReinforcementLearningABM, agent_types; 
                training_mode=:sequential, kwargs...) → ReinforcementLearningABM

Train the specified agent types in the model using reinforcement learning.

## Arguments
- `model::ReinforcementLearningABM`: The model to train
- `agent_types`: Agent type or vector of agent types to train

## Keyword Arguments  
- `training_mode::Symbol`: `:sequential` or `:simultaneous` (default: `:sequential`)
- `training_steps::Int`: Number of training steps per agent (default: 50_000)
- `solver_type::Symbol`: Type of RL solver to use (`:PPO`, `:DQN`, `:A2C`) (default: `:PPO`)
- `solver_params::Dict`: Dict of custom solver parameters for each agent type or global parameters
- `custom_networks::Dict`: Dict of custom neural networks for each agent type
- `custom_solvers::Dict`: Dict of custom solvers for each agent type
- Other arguments passed to the training functions

## Returns
- `ReinforcementLearningABM`: The model with trained policies stored

## Notes
- `max_steps` is read directly from the RL configuration (`model.rl_config[][:max_steps]`)
- Episode termination is controlled by the RL environment wrapper using the config value
- Cannot override `max_steps` during training - it must be set in the RL configuration

## Examples
```julia
# Basic training with custom solver parameters
train_model!(model, MyAgent; 
    training_steps=10000,
    solver_params=Dict(:ΔN => 100, :log => (period=500,)))

# Per-agent-type solver parameters
train_model!(model, [Agent1, Agent2]; 
    solver_params=Dict(
        Agent1 => Dict(:ΔN => 100),
        Agent2 => Dict(:ΔN => 200)
    ))
```
"""
function train_model! end

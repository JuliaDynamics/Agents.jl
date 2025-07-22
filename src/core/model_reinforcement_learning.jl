export ReinforcementLearningABM, RLAgent
export train_model!, get_trained_policies, set_rl_config!, step_rl!
export observation_to_vector, calculate_reward, is_terminal
export get_current_training_agent_type, get_current_training_agent, reset_model_for_episode!


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
    training_agent_types = [MyRLAgent]
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
- `observation_fn(model, agent_id, observation_radius)`: Function to get observations
- `observation_to_vector_fn(observation)`: Function to convert observations to vectors
- `reward_fn(env, agent, action, initial_model, final_model)`: Function to calculate rewards  
- `terminal_fn(env)`: Function to check if episode should terminate
- `action_spaces`: Dict mapping agent types to their action spaces
- `observation_spaces`: Dict mapping agent types to their observation spaces  
- `training_agent_types`: Vector of agent types to train
- `max_steps`: Maximum steps per episode
- `observation_radius`: Radius for local observations
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
    set_rl_config!(model::ReinforcementLearningABM, config)

Set the RL configuration for the model.
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
    get_trained_policies(model::ReinforcementLearningABM)

Get the dictionary of trained policies for each agent type.
"""
get_trained_policies(model::ReinforcementLearningABM) = model.trained_policies

"""
    step_rl!(model::ReinforcementLearningABM, n::Int=1)

Step the model forward using trained RL policies for agent behavior.
If policies are not available for some agent types, they will use random actions.

Note: This function provides explicit RL stepping. You can also use the standard 
`step!(model, n)` which will automatically use RL policies when available through
the `step_ahead_rl!` infrastructure.
"""
function step_rl!(model::ReinforcementLearningABM, n::Int=1)
    if isnothing(model.rl_config[])
        error("RL configuration not set. Use set_rl_config! first.")
    end

    for _ in 1:n
        # Step agents using RL policies
        for agent in allagents(model)
            rl_agent_step!(agent, model)
        end

        # Step the model
        model.model_step(model)

        # Increment time
        model.time[] += 1
    end
end

"""
    rl_agent_step!(agent, model)

Default agent stepping function for RL agents. This will use trained policies
if available, otherwise fall back to random actions.
"""
function rl_agent_step!(agent, model)
    if model isa ReinforcementLearningABM
        agent_type = typeof(agent)

        if haskey(model.trained_policies, agent_type) && !isnothing(model.rl_config[])
            # Use trained policy
            config = model.rl_config[]
            obs = config.observation_fn(model, agent.id, get(config, :observation_radius, 2))
            obs_vec = config.observation_to_vector_fn(obs)

            # Check if Crux is available before using it
            if isdefined(Main, :Crux)
                action = Main.Crux.action(model.trained_policies[agent_type], obs_vec)
            else
                error("Crux is not available. Please import Crux before using trained RL policies.")
            end

            config.agent_step_fn(agent, model, action[1])
        else
            # Fall back to random behavior
            if !isnothing(model.rl_config[]) && haskey(model.rl_config[].action_spaces, agent_type)
                action_space = model.rl_config[].action_spaces[agent_type]
                action = rand(abmrng(model), action_space.vals)
                model.rl_config[].agent_step_fn(agent, model, action)
            else
                # Do nothing if no RL configuration available
                return
            end
        end
    else
        error("rl_agent_step! can only be used with ReinforcementLearningABM models.")
    end
end

"""
    get_current_training_agent_type(model::ReinforcementLearningABM)
    
Get the currently training agent type.
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
    get_current_training_agent(model::ReinforcementLearningABM)

Get the current agent being trained.
Note: current_training_agent_id is a counter/index that cycles through agents of the training type,
not the actual agent ID. 
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
        empty!(model.agents)
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


export train_model!

"""
    setup_rl_training(model::ReinforcementLearningABM, agent_type; 
        training_steps=50_000,
        value_network=nothing,
        policy_network=nothing,
        solver=nothing,
        solver_type=:PPO,
        solver_params=Dict()
    )

Set up RL training for a specific agent type using the ReinforcementLearningABM directly.
Returns a wrapped environment compatible with POMDPs training algorithms.
"""
function setup_rl_training end

"""
    train_agent_sequential(model::ReinforcementLearningABM, agent_types; 
        training_steps=50_000,
        custom_networks=Dict(),
        custom_solvers=Dict(),
        solver_types=Dict(),
        solver_params=Dict()
    )

Train multiple agent types sequentially using the ReinforcementLearningABM, where each 
subsequent agent is trained against the previously trained agents.
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
    )

Train multiple agent types simultaneously using the ReinforcementLearningABM with 
alternating batch updates.
"""
function train_agent_simultaneous end

## Helper Functions for Custom Neural Networks

"""
    process_solver_params(solver_params, agent_type)

Process solver parameters that can be either global or per-agent-type.
Returns the parameters specific to the given agent type.
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
    create_value_network(input_dims, hidden_layers=[64, 64], activation=relu)

Create a custom value network with specified architecture.
"""
function create_value_network end

"""
    create_policy_network(input_dims, output_dims, action_space, hidden_layers=[64, 64], activation=relu)

Create a custom policy network with specified architecture.
"""
function create_policy_network end

"""
    create_custom_solver(solver_type, custom_params)

Create a custom solver with specified parameters.
"""
function create_custom_solver end


"""
    train_model!(model::ReinforcementLearningABM, agent_types; 
                training_mode=:sequential, kwargs...)

Train the specified agent types in the model using reinforcement learning.

## Arguments
- `model`: The ReinforcementLearningABM to train
- `agent_types`: Agent type or vector of agent types to train

## Keyword Arguments  
- `training_mode`: `:sequential` or `:simultaneous` (default: `:sequential`)
- `training_steps`: Number of training steps per agent (default: 50_000)
- `solver_type`: Type of RL solver to use (`:PPO`, `:DQN`, `:A2C`) (default: `:PPO`)
- `solver_params`: Dict of custom solver parameters for each agent type or global parameters
- `custom_networks`: Dict of custom neural networks for each agent type
- `custom_solvers`: Dict of custom solvers for each agent type
- Other arguments passed to the training functions

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

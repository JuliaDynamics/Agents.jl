module AgentsRL

using Agents, Crux, POMDPs, Flux

# Import reinforcement learning functions from the extension
include("src/rl_utils.jl")
include("src/rl_training_functions.jl")
include("src/model_reinforcement_learning.jl")
include("src/step_reinforcement_learning.jl")

# Export relevant functions and types
export ReinforcementLearningABM
export RLEnvironmentWrapper, wrap_for_rl_training
export train_model!, step_rl!, copy_trained_policies!
export set_rl_config!, get_trained_policies
export get_current_training_agent_type, get_current_training_agent, reset_model_for_episode!
export setup_rl_training, train_agent_sequential, train_agent_simultaneous
export rl_step!, get_observation, observation_to_vector, calculate_reward

end
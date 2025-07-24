# ReinforcementLearningABM: A New Agent-Based Model Type

## Overview

The `ReinforcementLearningABM` is a new model type that extends the capabilities of `StandardABM` by integrating reinforcement learning (RL) functionality directly into the agent-based modeling framework. This model type provides a seamless way to train agents using RL algorithms while maintaining full compatibility with the existing Agents.jl ecosystem.

## Key Features

### 1. **Integrated RL Training**

- Built-in support for training agents using various RL algorithms (PPO, DQN, A2C)
- Automatic integration with POMDPs.jl and Crux.jl

### 2. **Multi-Agent Learning Support**

- Train multiple agent types simultaneously or sequentially
- Support for heterogeneous agents with different action and observation spaces
- Automatic policy management for trained agents

### 3. **Flexible Architecture**

- Inherits all functionality from `StandardABM`
- Optional RL functionality - can be used as a regular ABM when RL is not needed

### 4. **Easy Configuration**

- Simple configuration system for RL components
- Customizable observation functions, reward functions, and termination conditions
- Support for custom neural network architectures

## Architecture

```
ReinforcementLearningABM
├── StandardABM components
│   ├── agents, space, scheduler, properties, rng, etc.
├── RL-specific components
│   ├── rl_config: Configuration for RL training
│   ├── trained_policies: Storage for trained policies
│   ├── training_history: Record of training progress
│   ├── is_training: Training mode flag
```

## Dependencies

The RL functionality requires:

- `POMDPs.jl`: For the POMDP interface
- `Crux.jl`: For RL algorithms and neural networks
- `Flux.jl`: For neural network components

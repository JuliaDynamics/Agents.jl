# Tutorial

Agents.jl is composed of components for building models, building and managing space structures, collecting data, running batch simulations, and data visualization.

Agents.jl structures simulations in three components:

1. An [`AgentBasedModel`](@ref) instance.
1. A space instance.
1. A subtype of [`AbstractAgent`](@ref) for the agents.

To run simulations and collect data, the following are also necessary

4. Stepping functions that controls how the agents and the model evolve.
5. Specifying which data should be collected from the agents and/or the model.

## 1. The model

```@docs
AgentBasedModel
```

## [2. The space](@id Space)
Agents.jl offers several possibilities for the space the agents live in, separated into discrete and continuous categories (notice that using a space is not actually necessary).

The discrete possibilities are

```@docs
GraphSpace
GridSpace
```

and the continuous version is
```@docs
ContinuousSpace
```

## 3. The agent

```@docs
AbstractAgent
```

The agent type **must** be mutable. Once an Agent is created it can be added to a model using e.g. [`add_agent!`](@ref).
Then, the agent can interact with the model and the space further by using
e.g. [`move_agent!`](@ref) or [`kill_agent!`](@ref).

For more functions visit the [API](@ref) page.

## 4. Evolving the model

Any ABM model should have at least one and at most two step functions.
An _agent step function_ is always required.
Such an agent step function defines what happens to an agent when it activates.
Sometimes we also need a function that changes all agents at once, or changes a model property. In such cases, we can also provide a _model step function_.

An agent step function should only accept two arguments: first, an agent object, and second, a model object.

The model step function should accept only one argument, that is the model object.
To use only a model step function, users can use the built-in `dummystep` as the agent step function.

After you have defined these two functions, you evolve your model with `step!`:
```@docs
step!
dummystep
```

## 5. Collecting data
Running the model and collecting data while the model runs is done with the [`run!`](@ref) function. Besides `run!`, there is also the [`paramscan`](@ref) function that performs data collection, while scanning ranges of the parameters of the model.

```@docs
run!
```

The [`run!`](@ref) function has been designed for maximum flexibility: nearly all scenarios of data collection are possible whether you need agent data, model data, aggregating model data, or arbitrary combinations.

This means that [`run!`](@ref) has not been designed for maximum performance (or minimum memory allocation). However, we also expose a simple data-collection API (see [Data collection](@ref)), that gives users even more flexibility, allowing them to make their own "data collection loops" arbitrarily calling `step!` and collecting data as needed and to the data structure that they need.


## An educative example
A simple, education-oriented example of using the basic Agents.jl API is given in [Schelling's segregation model](@ref). There the visualization aspect is also discussed.

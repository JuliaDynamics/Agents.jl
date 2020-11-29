# Tutorial

Agents.jl is composed of components for building models, building and managing space structures, collecting data, running batch simulations, and data visualization.

Agents.jl structures simulations in three components:

1. An [`AgentBasedModel`](@ref) instance.
1. A [space](@ref Space) instance.
1. A subtype of [`AbstractAgent`](@ref) for the agents.

To run simulations and collect data, the following are also necessary

4. Stepping functions that controls how the agents and the model evolve.
5. Specifying which data should be collected from the agents and/or the model.

## 1. The model

```@docs
AgentBasedModel
```

## [2. The space](@id Space)
Agents.jl offers several possibilities for the space the agents live in.
In addition, it is straightforward to implement a fundamentally new type of space, see [Developer Docs](@ref).

Spaces are separated into `DisreteSpace`s (which by definition have a **finite** amount of **possible positions**) and continuous spaces.
Thus, it is common for a specific position to contain several agents.

### Discrete spaces
```@docs
GraphSpace
GridSpace
```

### Continuous spaces
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
A _model step function_ is required by default.
The model step function should accept only one argument, that is the model object.

Optionally, we can also provide a _agent step function_, which defines what happens to
an agent when it activates. An agent step function should only accept two arguments:
first, an agent object, and second, a model object.

Sometimes models are simple enough, that changing agent properties is all that's
required. In these cases, users can use the built-in [`dummystep`](@ref) as the model
step function, to ignore any dynamics here.

After you have defined these two functions, you evolve your model with `step!`:
```@docs
step!
dummystep
```

!!! note "Current step number"
    Notice that the current step number is not explicitly given to the `model_step!`
    function, because this is useful only for a subset of ABMs. If you need the
    step information, implement this by adding a counting parameter into the model
    `properties`, and incrementing it by 1 each time `model_step!` is called.
    An example can be seen in the `model_step!` function of [Daisyworld](@ref),
    where a `tick` is increased at each step.

## 5. Collecting data
Running the model and collecting data while the model runs is done with the [`run!`](@ref) function. Besides `run!`, there is also the [`paramscan`](@ref) function that performs data collection, while scanning ranges of the parameters of the model.

```@docs
run!
```

The [`run!`](@ref) function has been designed for maximum flexibility: nearly all scenarios of data collection are possible whether you need agent data, model data, aggregating model data, or arbitrary combinations.

This means that [`run!`](@ref) has not been designed for maximum performance (or minimum memory allocation). However, we also expose a simple data-collection API (see [Data collection](@ref)), that gives users even more flexibility, allowing them to make their own "data collection loops" arbitrarily calling `step!` and collecting data as needed and to the data structure that they need.


## An educative example
A simple, education-oriented example of using the basic Agents.jl API is given in [Schelling's segregation model](@ref), also discussing in detail how to visualize your ABMs.

Each of the examples listed within this documentation are designed to showcase different ways of interacting with the API.
If you are not sure about how to use a particular function, most likely one of the examples can show you how to interact with it.

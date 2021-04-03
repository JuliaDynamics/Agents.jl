# Tutorial

In Agents.jl a central structure maps unique IDs (integers) to agent instances, similar to a dictionary. During the simulation, the model evolves in discrete steps. During one step, the user decides which agents will act, how will they act, how many times, and whether any model-level properties will be adjusted.
Once the time evolution is defined, collecting data during time evolution is straightforward by simply stating which data should be collected.

In the spirit of simple design, all of this is done by defining simple Julia data types, like basic functions, structs and dictionaries.

To set up an ABM simulation in Agents.jl, a user only needs to follow these steps:

1. Choose in what kind of space the agents will live in, for example a graph, a grid, etc. Several spaces are provided by Agents.jl and can be initialized immediately.
1. Define the agent type (or types, for mixed models) that will populate the ABM. This is defined as a standard Julia `struct` and contains two mandatory fields `id, pos`, with the position field being appropriate for the chosen space.
3. The created agent type, the chosen space, and optional additional model level properties (typically in the form of a dictionary) are provided in our universal structure [`AgentBasedModel`](@ref). This instance defines the model within an Agents.jl simulation. Further options are also available, regarding schedulers and random number generation.
4. Provide functions that govern the time evolution of the ABM. A user can provide an agent-stepping function, that acts on each agent one by one, and/or model-stepping function, that steps the entire model as a whole. These functions are standard Julia functions that take advantage of the Agents.jl [API](@ref).
5. Collect data. To do this, specify which data should be collected, by providing one standard Julia `Vector` of data-to-collect for agents, and another one for the model, for example `[:mood, :wealth]`. The outputted data are in the form of a `DataFrame`.


## [1. The space](@id Space)
Agents.jl offers several possibilities for the space the agents live in.
In addition, it is straightforward to implement a fundamentally new type of space, see [Developer Docs](@ref).

The available spaces are:

- [`GraphSpace`](@ref): Agent positions are equivalent with nodes of a graph/network.
- [`GridSpace`](@ref): Space is discretized into boxes, typical style for cellular automata.
- [`ContinuousSpace`](@ref): Truthful representation of continuous space, regarding location, orientation, and identification of neighboring agents.
- [`OpenStreetMapSpace`](@ref): A space based on Open Street Map, where agents are confined to move along streets of the map, using real-world meter values for the length of each street.

One simply initializes an instance of a space, e.g. with `grid = GridSpace((10, 10))` and passes that into [`AgentBasedModel`](@ref). See each individual space for all its possible arguments.


## 2. The agent type

```@docs
AbstractAgent
```

Once an agent is created it can be added to a model using e.g. [`add_agent!`](@ref).
Then, the agent can interact with the model and the space further by using e.g. [`move_agent!`](@ref) or [`kill_agent!`](@ref).

For more functions visit the [API](@ref) page.

## 3. The model

```@docs
AgentBasedModel
```


## 4. Evolving the model

Any ABM model should have at least one and at most two step functions.
An _agent step function_ is required by default.
Such an agent step function defines what happens to an agent when it activates.
Sometimes we also need a function that changes all agents at once, or changes a model property. In such cases, we can also provide a _model step function_.

An agent step function should only accept two arguments: first, an agent object, and second, a model object.

The model step function should accept only one argument, that is the model object.
To use only a model step function, users can use the built-in [`dummystep`](@ref) as the agent step function. This is typically the case for [Advanced stepping](@ref).

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

### Advanced stepping
The interface of [`step!`](@ref), which allows the option of both `agent_step!` and `model_step!` is driven mostly by convenience. In principle, the `model_step!` function by itself can perform all operations related with stepping the ABM.
However, for many models, this simplified approach offers the benefit of not having to write an explicit loop over existing agents inside the `model_step!`.
Most of the examples in our documentation can be expressed using an independent `agent_step!` and `model_step!` function.

On the other hand, more advanced models require special handling for scheduling, or may need to schedule several times and act on different subsets of agents with different functions.
In such a scenario, it is more sensible to provide only a `model_step!` function (and use `dummystep` as `agent_step!`), where all configuration is contained within.
Notice that if you follow this road, the argument `scheduler` given to [`AgentBasedModel`](@ref) somewhat loses its meaning.

Here is an example:
```julia
function complex_step!(model)
    for a in scheduler1(model)
        agent_step1!(a, model)
    end
    intermediate_model_action!(model)
    for a in scheduler2(model)
        agent_step2!(a, model)
    end
    final_model_action!(model)
end

step!(model, dummystep, complex_step!, n)
```

For defining your own schedulers, see [Schedulers](@ref).

## 5. Collecting data
Running the model and collecting data while the model runs is done with the [`run!`](@ref) function. Besides `run!`, there is also the [`paramscan`](@ref) function that performs data collection, while scanning ranges of the parameters of the model.

```@docs
run!
```

The [`run!`](@ref) function has been designed for maximum flexibility: nearly all scenarios of data collection are possible whether you need agent data, model data, aggregating model data, or arbitrary combinations.

This means that [`run!`](@ref) has not been designed for maximum performance (or minimum memory allocation). However, we also expose a simple data-collection API (see [Data collection](@ref)), that gives users even more flexibility, allowing them to make their own "data collection loops" arbitrarily calling `step!` and collecting data as, and when, needed.

As your models become more complex, it may not be advantageous to use lots of helper functions in the global scope to assist with data collection.
If this is the case in your model, here's a helpful tip to keep things clean:

```julia
function assets(model)
    total_savings(model) = model.bank_balance + sum(model.assets)
    function stategy(model)
        if model.year == 0
            return model.initial_strategy
        else
            return get_strategy(model)
        end
    end
    return [:age, :details, total_savings, strategy]
end
run!(model, agent_step!, model_step!, 10; mdata = assets(model))
```

## Seeding and Random numbers

Each model created by [`AgentBasedModel`](@ref) provides a random number generator pool `model.rng` which by default coincides with the global RNG.
For performance reasons, one should never use `rand()` without using a pool, thus throughout our examples we use `rand(model.rng)` or `rand(model.rng, 1:10, 100)`, etc.

Another benefit of this approach is deterministic models that can be ran again and yield the same output.
To do this, either always pass a specifically seeded RNG to the model creation, e.g. `MersenneTwister(1234)`, or call `seed!(model, 1234)` (with any number) after creating the model but before actually running the simulation.

Passing `RandomDevice()` will use the system's entropy source (coupled with hardware like [TrueRNG](https://ubld.it/truerng_v3) will invoke a true random source, rather than pseudo-random methods like `MersenneTwister`). Models using this method cannot be repeatable, but avoid potential biases of pseudo-randomness.

## An educative example
A simple, education-oriented example of using the basic Agents.jl API is given in [Schelling's segregation model](@ref), also discussing in detail how to visualize your ABMs.
For a quick reference concerning the main concepts of agent based modelling, and how the Agents.jl examples implement each one, take a look at the [Overview of Examples](@ref) page.

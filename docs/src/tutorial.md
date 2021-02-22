# Tutorial

Agents.jl is composed of components for building models, building and managing space structures, collecting data, running batch simulations, and data visualization.

Agents.jl structures simulations in three components:

1. An [`AgentBasedModel`](@ref) instance.
1. A [space](@ref Space) instance.
1. A subtype of [`AbstractAgent`](@ref) for the agents.

To run simulations and collect data, the following are also necessary

4. Stepping functions that controls how the agents and the model evolve.
5. Specifying which data should be collected from the agents and/or the model.

So, in order to set up and run an ABM simulation with Agents.jl, you typically need to define a structure, function, or parameter collection for steps 1-3, define the rules of the agent evolution for step 4, and then declare which parameters of the model and the agents should be collected as data during step 5.

## 1. The model

```@docs
AgentBasedModel
```

## [2. The space](@id Space)
Agents.jl offers several possibilities for the space the agents live in.
In addition, it is straightforward to implement a fundamentally new type of space, see [Developer Docs](@ref).

Spaces are separated into disrete spaces (which by definition have a **finite** amount of **possible positions**) and continuous spaces.
In discrete spaces it is common for a specific position to contain several agents.

The available spaces are:

- [`GraphSpace`](@ref)
- [`GridSpace`](@ref)
- [`ContinuousSpace`](@ref)
- [`OpenStreetMapSpace`](@ref)

One simply initializes an instance of a space, e.g. with `grid = GridSpace((10, 10))` and passes that into [`AgentBasedModel`](@ref).

## 3. The agent

```@docs
AbstractAgent
```

Once an Agent is created it can be added to a model using e.g. [`add_agent!`](@ref).
Then, the agent can interact with the model and the space further by using
e.g. [`move_agent!`](@ref) or [`kill_agent!`](@ref).

For more functions visit the [API](@ref) page.

## 4. Evolving the model

Any ABM model should have at least one and at most two step functions.
An _agent step function_ is required by default.
Such an agent step function defines what happens to an agent when it activates.
Sometimes we also need a function that changes all agents at once, or changes a model property. In such cases, we can also provide a _model step function_.

An agent step function should only accept two arguments: first, an agent object, and second, a model object.

The model step function should accept only one argument, that is the model object.
To use only a model step function, users can use the built-in [`dummystep`](@ref) as the agent step function.

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
For example
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

For defining your own scheduler, see [Schedulers](@ref).

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

## An educative example
A simple, education-oriented example of using the basic Agents.jl API is given in [Schelling's segregation model](@ref), also discussing in detail how to visualize your ABMs.

Each of the examples listed within this documentation are designed to showcase different ways of interacting with the API.
If you are not sure about how to use a particular function, most likely one of the examples can show you how to interact with it.

For a quick reference concerning the main concepts of agent based modelling, and how the Agents.jl examples implement each one, take a look at the [Overview of Examples](@ref) page.

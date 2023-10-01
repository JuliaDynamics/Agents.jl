# Tutorial

!!! tip "YouTube video"
      * This Tutorial is also available as a YouTube video: [https://youtu.be/fgwAfAa4kt0](https://youtu.be/fgwAfAa4kt0)


In Agents.jl a central abstract structure called `AgentBasedModel` contains all information necessary to run a simulation: the evolution rule (also called dynamic rule), the agents of the simulation, and other global properties relevant to the simulation. `AgentBasedModel`s map unique IDs (integers) to agent instances.
During the simulation, the model evolves in discrete steps. During one step, the user decides which agents will act, how they will act, how many times, and whether any model-level properties will be adjusted.
Once the time evolution is defined, collecting data during time evolution is straightforward by simply stating which data should be collected.

In the spirit of simple design, all of this is done by defining simple Julia data types, like basic functions, structs and dictionaries.

To set up an ABM simulation in Agents.jl, a user only needs to follow these steps:

1. Choose what **kind of space** the agents will live in, for example a graph, a grid, etc. Several spaces are provided by Agents.jl and can be initialized immediately.
2. Define the **agent type** (or types, for mixed models) that will populate the ABM. Agent types are Julia `mutable struct`s that are created with [`@agent`](@ref). The types must contain some mandatory fields, which is ensured by using [`@agent`](@ref). The remaining fields of the agent type are up to the user's choice.
3. Define the **evolution rule**, i.e., how the model evolves in time. The evolution rule needs to be provided as at least one, or at most two functions: an agent stepping function, that acts on each agent one by one, and/or a model stepping function, that steps the entire model as a whole. These functions are standard Julia functions that take advantage of the Agents.jl [API](@ref).
4. Initialize an **agent based model instance** that contains created agent type, the chosen space, the evolution rule, other optional additional model-level properties, and other simulation tuning properties like schedulers or random number generators. The most common model type is [`StandardABM`](@ref), but more specialized model types are also available, see [`AgentBasedModel`](@ref).
5. _(Trivial)_ **evolve the model**.
6. _(Optional)_ **Visualize the model** and animate its time evolution. This can help checking that the model behaves as expected and there aren't any mistakes, or can be used in making figures for a paper/presentation.
7. **Collect data**. To do this, specify which data should be collected, by providing one standard Julia `Vector` of data-to-collect for agents, for example `[:mood, :wealth]`, and another one for the model. The agent data names are given as the keyword `adata` and the model as keyword `mdata` to the function [`run!`](@ref). This function outputs collected data in the form of a `DataFrame`.

If you're planning of running massive simulations, it might be worth having a look at the [Performance Tips](@ref) after familiarizing yourself with Agents.jl.

## [1. The space](@id Space)

Agents.jl offers several possibilities for the space the agents live in.
In addition, it is straightforward to implement a fundamentally new type of space, see [Creating a new space type](@ref).

The available spaces are listed in the [Available spaces](@ref) part of the API.
An example of a space is [`OpenStreetMapSpace`](@ref). It is based on Open Street Map, where agents are confined to move along streets of the map, using real-world values for the length of each street.

After deciding on the space, one simply initializes an instance of a space, e.g. with `grid = GridSpace((10, 10))` and passes that into [`AgentBasedModel`](@ref). See each individual space for all its possible arguments.

## 2. The agent type(s)

Agents in Agents.jl are instances of user-defined types. While the majority of Agents.jl [API](@ref) is based on a functional design, accessing agent properties is done with the simple field-access Julia syntax. For example, the (named) property `weight` of an agent can be obtained as `agent.weight`.

To create agent types, and define what properties they should have, the user needs to use the [`@agent`](@ref) macro, which ensures that agents have the minimum amount of required necessary properties to function within a given space and model by inheriting pre-defined agent types suited for each type of space.
The macro usage may seem intimidating at first, but it is in truth very simple!
For example,
```julia
@agent struct Person(GridAgent{2})
    age::Int
    money::Float64
end
```
would make an agent type with named properties `age, money`, while also inheriting all named properties of the `GridAgent{2}` predefined type (which is necessary for simulating agents in a two-dimensional grid space).

```@docs
@agent
AbstractAgent
```

## 3.1 The evolution rule - basics

The evolution rule may always be provided as one standard Julia function that inputs the model and modifies it _in-place_, according to the rules of the simulation. Such a **model stepping function** will itself likely call functions from the Agents.jl [API](@ref) and may look like
```julia
function model_step!(model)
    exchange = model.exchange # obtain the `exchange` model property
    agent = model[5] # obtain agent with ID = 5
    # Iterate over neighboring agents (within distance 1)
    for neighbor in nearby_agents(model, agent, 1)
        transfer = minimum(neighbor.money, exchange)
        agent.money += transfer
        neighbor.money -= transfer
    end
    return # function end. As it is in-place it `return`s nothing.
end
```
This function will be called once per simulation step.

As you can see, the above defined model stepping function did not operate on all agents of the model, only on agent with ID 5 and its spatial neighbors. Typically you would want to operate on more agents. There is a simple automated way to do this (section 3.2), and a non-automated, but fully-configurable way to do this (section 3.3).

## 3.2 The evolution rule - agent stepping function

In Agents.jl it is also possible to provide an **agent stepping function**.
This feature enables scheduling agents automatically given some scheduling rule, skipping the agents that were scheduled to act but have been removed from the model (due to e.g., the actions of other agents), and also allows optimizations that are based on the specific type of `AgentBasedModel`.

An agent stepping function defines what happens to an agent when it activates.
It inputs two arguments `agent, model` and operates in place on the `agent` and the `model`.
This function will be applied to every `agent` that has been scheduled by the model's scheduler.
A scheduler simply creates an iterator of agent IDs at each simulation step, possibly taking into account the current model state.
Several schedulers are provided out-of-the-box by Agents.jl, see [Schedulers](@ref).

Given the example above, an agent stepping function that would perform a similar currency exchange between agents would look like
```julia
function agent_step!(agent, model)
    exchange = model.exchange # obtain the `exchange` model property
    # Iterate over neighboring agents (within distance 1)
    for neighbor in nearby_agents(model, agent, 1)
        transfer = minimum(neighbor.money, exchange)
        agent.money += transfer
        neighbor.money -= transfer
    end
    agent.age += 1
    # if too old, pass fortune onto heir and remove from model
    if agent.age > 75
        heir = replicate!(agent, model)
        heir.age = 1
        remove_agent!(agent, modeL)
    end
    return # function end. As it is in-place it `return`s nothing.
end
```
and to activate all agents randomly once per simulation step, one would use `Schedulers.Randomly()` as the model scheduler.

We stress that in contrast to the above `model_step!`, this function will be called for _every_ scheduled agent, while `model_step!` will only be called _once_ per simulation step.
Naturally, you may define **both** an agent and a model stepping functions. In this case the model stepping function would perform model-wide actions that are not limited to a particular agent.

## [3.3 The evolution rule - advanced (manual scheduling)](@id manual_scheduling)

Some advanced models may require special handling for scheduling, or may need to schedule agents several times and act on different subsets of agents with different functions during a single simulation step.
In such a scenario, it is more sensible to provide only a model stepping function, where all the dynamics is contained within.

Here is an example:

```julia
function complex_step!(model)
    scheduler1 = Schedulers.Randomly()
    scheduler2 = user_defined_function_with_model_as_arg
    for id in schedule(model, scheduler1)
        agent_step1!(model[id], model)
    end
    intermediate_model_action!(model)
    for id in schedule(model, scheduler2)
        agent_step2!(model[id], model)
    end
    if model.step_counter % 100 == 0
        model_action_every_100_steps!(model)
    end
    final_model_action!(model)
    return
end
```

For defining your own schedulers, see [Schedulers](@ref).

!!! note "Current step number"
    Notice that the current step number is not explicitly given to the model stepping function, nor is contained in the model type, because this is useful only for a subset of ABMs.
    If you need the step information, implement this by adding a counting parameter into the model `properties`, and incrementing it by 1 each time the model stepping function is called.

## 4. The model

The ABM is an instance of a subtype of [`AgentBasedModel`](@ref), most typically simply a [`StandardABM`](@ref).
A model is created by passing all inputs of steps 1-3 into the model constructor.
Once the model is constructed, it can be populated by agents using the [`add_agent!`](@ref) function, which we highlight in the educative example below.

```@docs
AgentBasedModel
StandardABM
```

## 5. Evolving the model

After you have created an instance of an `AgentBasedModel`, it is rather trivial to evolve it by simply calling `step!` on it

```@docs
step!
```

## 5. Visualizations

Once you have defined a model and the stepping functions, you can visualize the model statically, or animate its time evolution straightforwardly in ~5 lines of code. This is discussed in a different page: [Visualizations and Animations for Agent Based Models](@ref). Furthermore, all models in the Examples showcase plotting.

## 6. Collecting data

Running the model and collecting data while the model runs is done with the [`run!`](@ref) function. Besides `run!`, there is also the [`paramscan`](@ref) function that performs data collection while scanning ranges of the parameters of the model, and the [`ensemblerun!`](@ref) that performs ensemble simulations and data collection.

```@docs
run!
```

The [`run!`](@ref) function has been designed for maximum flexibility: nearly all scenarios of data collection are possible, whether you need agent data, model data, aggregated data, or arbitrary combinations.

Nevertheless, we also expose a simple data-collection API (see [Data collection](@ref)), that gives users even more flexibility, allowing them to make their own "data collection loops" arbitrarily calling `step!` and collecting data as, and when, needed.

As your models become more complex, it may not be advantageous to use lots of helper functions in the global scope to assist with data collection.
If this is the case in your model, here's a helpful tip to keep things clean: use a generator function to collect data as instructed in the documentation string of [`run!`](@ref). For example:

```julia
function assets(model)
    total_savings(model) = model.bank_balance + sum(model.assets)
    function strategy(model)
        if model.year == 0
            return model.initial_strategy
        else
            return get_strategy(model)
        end
    end
    return [:age, :details, total_savings, strategy]
end
run!(model, agent_step!, model_step!, 10; mdata = assets)
```

## Seeding and Random numbers

Each ABM in Agents.jl contains a random number generator (RNG) instance that can be obtained with `abmrng(model)`.
For performance and reproducibility reasons, one should never use `rand()` without using the RNG, thus throughout our examples we use `rand(abmrng(model))` or `rand(abmrng(model), 1:10, 100)`, etc.

Another benefit of this approach is deterministic models that can be run again and yield the same output.
To do this, always pass a specifically seeded RNG to the model creation, e.g. `rng = Random.MersenneTwister(1234)` and then give this `rng` to the model creation.

## An educative example

A simple, education-oriented example of using the basic Agents.jl API is given in [Schelling's segregation model](@ref).

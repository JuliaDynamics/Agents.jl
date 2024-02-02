# # Tutorial

# This is the main overarching tutorial for Agents.jl. It will walk you through the
# typical workflow of doing agent based modelling (ABM) using Agents.jl,
# while introducing and explaining the core components of Agents.jl.
# The tutorial will utilize various versions of the [Schelling segregation model](https://en.wikipedia.org/wiki/Schelling%27s_model_of_segregation)
# as an example to apply the concepts we learn.

# ## Core steps of an Agents.jl simulation

# In Agents.jl a central abstract structure called `AgentBasedModel` contains all
# information necessary to run a simulation: the evolution rule (also called dynamic rule),
# the agents of the simulation, the space the agents move and interact in,
# and other model-level properties relevant to the simulation.

# An Agents.jl simulation is composed of first building such an `AgentBasedModel`
# (steps 1-4 below) and then evolving it and analyzing it (steps 5-7 below):

# 1. Choose what **kind of space** the agents will live in, for example a graph, a grid,
#   etc. Several spaces are provided by Agents.jl and can be initialized immediately.
# 2. Define the **agent type** (or types, for mixed models) that will populate the ABM.
#   Agent types are Julia `mutable struct`s that are created with [`@agent`](@ref).
#   The types must contain some mandatory fields, which is ensured by using
#   [`@agent`](@ref). The remaining fields of the agent type are up to the user's choice.
# 3. Define the **evolution rule(s)**, i.e., how the model evolves in time.
#   The evolution rule(s) are always standard Julia functions that take advantage of
#   the Agents.jl [API](@ref).
#   The exact way one defines the evolution rules depends on the type of `AgentBasedModel`
#   used. Agents.jl allows simulations in both discrete time via [`StandardABM`](@ref)
#   as well as continuous time via [`EventQueueABM`](@ref). In this tutorial we will
#   learn the discrete-time version. See the [rock-paper-scissors](@ref eventbased_tutorial)
#   example for an introduction to the continuous time version.
# 4. Initialize an **`AgentBasedModel` instance** that contains the agent type(s), the
#   chosen space, the evolution rule(s), other optional additional model-level properties,
#   and other simulation tuning properties like schedulers or random number generators.
# 5. _(Trivial)_ **evolve the model** forwards in time.
# 6. _(Optional)_ **Visualize the model** and animate its time evolution.
#   This can help checking that the model behaves as expected and there aren't any mistakes,
#   or can be used in making figures for a paper/presentation.
# 7. **Collect data**. To do this, specify which data should be collected, by providing
#   one standard Julia `Vector` of data-to-collect for agents, for example
#   `[:mood, :wealth]`, and another one for the model. The agent data names are given as
#   the keyword `adata` and the model as keyword `mdata` to the function [`run!`](@ref).
#   This function outputs collected data in the form of a `DataFrame`.

# In the spirit of simple design, all of these steps are done by defining simple Julia
# data structures, like vectors, dictionaries, functions, or structs.
# This means that using Agents.jl comes with _transferrable_ knowledge to the whole
# Julia ecosystem. Indeed, looking at the "Integration examples" (see sidebar of online docs)
# Agents.jl can be readily used with any other Julia package, exactly because its design
# is based on existing, and widely established, Julia language concepts.

# ## The Schelling segregation model basic rules

# * A fixed pre-determined number of agents exist in the model.
# * Agents belong to one of two groups (1 or 2).
# * The agents live in a two-dimensional non-periodic grid.
# * Only one agent per position is allowed.
# * At each state pf the simulation,
#   each agent looks at its 8 neighboring positions (cardinal and diagonal directions).
#   It then counts how many neighboring agents belong to the same group (if any).
#   This leads to 8 neighboring positions per position (except at the edges of the grid).
# * If an agent has at least `min_to_be_happy` neighbors belonging to the same group,
#   then it becomes happy.
# * Else, the agent is unhappy and moves to a new random location in space
#   while respecting the 1-agent-per-position rule.

# In the following we will built this model following the aforementioned steps.
# The 0-th step of any Agents.jl simulation is to bring the package into scope:

using Agents

# ## Step 1: creating the space

# Agents.jl offers multiple spaces one can utilize to perform simulations,
# all of which are listed in the [available spaces section](@ref available_spaces).
# If we go through the list, we quickly realize that the space we need to use here is
# [`GridSpaceSingle`](@ref) which is a grid that allows only one agent per position.
# So, we can go ahead and create an instance of this type.
# We need to specify the total size of the grid, and also that the distance metric should be
# the Chebyshev one, which means that diagonal and orthogonal directions quantify
# as the same distance away. We also specify that the space should _not_ be periodic.

size = (10, 10)
space = GridSpaceSingle(size; periodic = false, metric = :chebyshev)

# ## Step 2: the `@agent` command

# Agents in Agents.jl are instances of user-defined `struct`s that subtype `AbstractAgent`.
# This means that agents are data containers that contain some particular data fields that are necessary
# to perform simulations with Agents.jl, as well as any other data field that
# the user requires. If an agent instance `agent` exists in the simulation
# then the data field named "weight" is obtained from the agent using `agent.weight`.
# This is standard Julia syntax to access the data field named "weight" for any data structure
# that contains such a field.

# To create agent types, and define what properties they should have, it is strongly
# recommended to use the [`@agent`](@ref) command. You can read its documentation in detail
# if you wish to understand it deeply. But the long story made sort is that this command
# ensures that agents have the minimum amount of required necessary properties
# to function within a given space and model by "inheriting" pre-defined agent properties
# suited for each type of space.

# The simplest syntax of [`@agent`] is (and see its documentation for all its capabilities):
# ```julia
# @agent struct YourAgentType(AgentTypeToInheritFrom) [<: OptionalSupertype]
#     extra_property::Float64 # annotating the type leads to optimal computational performance
#     other_extra_property_with_default::Bool = true
#     const other_extra_constant_property::Int
#     # etc...
# end
# ```

# The command may seem intimidating at first, but it is in truth very simple!
# For example,
# ```julia
# @agent struct Person(GridAgent{2})
#     age::Int
#     money::Float64
# end
# ```
# would make an agent type with named properties `age, money`,
# while also inheriting all named properties of the `GridAgent{2}` predefined type.
# These properties are `(id::Int, pos::Tuple{Int, Int})` and are necessary for simulating
# agents in a two-dimensional grid space.
# The documentation of each space describes what pre-defined agent one needs to inherit from
# in the `@agent` command, which is how we found that we need to put `GridAgent{2}` there.
# The `{2}` is simply an annotation that the space is 2-dimensional, as Agents.jl allows
# simulations in arbitrary-dimensional spaces.


# ## Step 2: creating the agent type

# With this knowledge, let's now make the agent type for the Schelling segregation model.
# According to the rules of the game, the agent needs to have two auxilary properties:
# its mood (boolean) and the group it belongs to (integer). The agent also needs to
# inherit from `GridAgent{2}` as in the example above. So, we define:

@agent struct SchellingAgent(GridAgent{2})
    mood::Bool # whether the agent is happy in its position
    group::Int # The group of the agent, determines mood as it interacts with neighbors
end

# Let's explitily print the fields of the data structure `SchellingAgent` that we created:

for (name, type) in zip(fieldnames(SchellingAgent), fieldtypes(SchellingAgent))
    println(name, "::", type)
end

# All these fields can be accessed during the simulation, but it is important
# to keep in mind that `id` cannot be modified, and `pos` must never be modified
# directly; only through valid API functions such as [`move_agent!`](@ref).

# For example, if we initialize such an agent

example_agent = SchellingAgent(id = 1, pos = (2, 3), mood = true, group = 1)

# we can obtain

example_agent.mood

# and set

example_agent.mood = false

# but can't set the `id`:

```julia
example_agent.id = 2
```
```
ERROR: setfield!: const field .id of type SchellingAgent cannot be changed
Stacktrace:
 [1] setproperty!(x::SchellingAgent, f::Symbol, v::Int64)
   @ Base .\Base.jl:41
```

# ## Step 3:

# ## Step 3: form of the evolution rule(s) in discrete time

# The form of the evolution rule(s) depends on the type of [`AgentBasedModel`](@ref)
# we want to use. For the example we are following here, we will use
# [`StandardABM`](@ref). For this, time is discrete. In this case,
# the evolution rule needs to be provided as at least one, or at most
# two functions: an agent stepping function, that acts on scheduled agents one by one, and/or
# a model stepping function, that steps the entire model as a whole.
# These functions are standard Julia functions that take advantage of the
# Agents.jl [API](@ref). At each discrete step of the simulation,
# the agent stepping function is applied once to all activated agents,
# and the model stepping function is applied once to the model.
# The model stepping function may also modify arbitrarily many
# agents since at any point all agents of the simulation are accessible
# from the agent based model.

# To give you an idea, here is an example of a model stepping function:
# ```julia
# function model_step!(model)
#     exchange = model.exchange # obtain the `exchange` model property
#     agent = model[5] # obtain agent with ID = 5
#     # Iterate over neighboring agents (within distance 1)
#     for neighbor in nearby_agents(model, agent, 1)
#         transfer = minimum(neighbor.money, exchange)
#         agent.money += transfer
#         neighbor.money -= transfer
#     end
#     return # function end. As it is in-place it `return`s nothing.
# end
# ```

# This model stepping function did not operate on all agents of the model,
# only on agent with ID 5 and its spatial neighbors.
# Typically you would want to operate on more agents, which is why
# Agents.jl also allows the concept of the agent stepping function.
# This feature enables scheduling agents automatically given some
# scheduling rule, skipping the agents that were scheduled to act but have been
# removed from the model (due to e.g., the actions of other agents),
# and also allows optimizations that are based on the specific type of `AgentBasedModel`.

# Given the example above, an agent stepping function that would perform a similar
# currency exchange between agents would look like
# ```julia
# function agent_step!(agent, model)
#     exchange = model.exchange # obtain the `exchange` model property
#     # Iterate over neighboring agents (within distance 1)
#     for neighbor in nearby_agents(model, agent, 1)
#         transfer = minimum(neighbor.money, exchange)
#         agent.money += transfer
#         neighbor.money -= transfer
#     end
#     agent.age += 1
#     # if too old, pass fortune onto heir and remove from model
#     if agent.age > 75
#         heir = replicate!(agent, model)
#         heir.age = 1
#         remove_agent!(agent, modeL)
#     end
#     return # function end. As it is in-place it `return`s nothing.
# end
# ```

# We stress that in contrast to the above `model_step!`,
# `agent_step!` will be called for _every_ scheduled agent,
# while `model_step!` will only be called _once_ per simulation step.
# By default, all agents in the model are scheduled once per step,
# but we will discuss this more later in the "scheduling" section.

# At least one of the model or agent stepping functions must be provided.

# ## Step 3: application to the Schelling model

# Great, lets now apply this knowledge to create the evolution rule
# for the Schelling segregation model. Reading the rules of the game
# we realize that there is no need for a model stepping function.
# Thus, we define the agent stepping function only:

function agent_step!(agent, model)
    ## Here we access a model-level property `min_to_be_happy`.
    ## This will have an assigned value once we create the model.
    minhappy = model.min_to_be_happy
    count_neighbors_same_group = 0
    ## For each neighbor, get group and compare to current agent's group
    ## and increment `count_neighbors_same_group` as appropriately.
    ## Here `nearby_agents` (with default arguments) will provide an iterator
    ## over the nearby agents one grid point away, which are at most 8.
    for neighbor in nearby_agents(agent, model)
        if agent.group == neighbor.group
            count_neighbors_same_group += 1
        end
    end
    ## After counting the neighbors, decide whether or not to move the agent.
    ## If count_neighbors_same_group is at least the min_to_be_happy, set the
    ## mood to true. Otherwise, move the agent to a random position, and set
    ## mood to false.
    if count_neighbors_same_group ≥ minhappy
        agent.mood = true
    else
        agent.mood = false
        move_agent_single!(agent, model)
    end
    return
end

# Here we used some of the built-in functionality of Agents.jl, in particular:
# - [`nearby_positions`](@ref) that returns the neighboring position
#   on which the agent resides
# - [`move_agent_single!`](@ref) which moves # agents to random empty position on the grid
#   while respecting an at most 1 agent per position rule
# - `model[id]` which returns the agent with given `id` in the `model`,
# . `model.min_to_be_happy` which returns the model-level property named `min_to_be_happy`

# A full list of built-in functionality
# and their explanations are available in the [API](@ref) page.

# ## Step 4: the `AgentBasedModel`

# ## Step 4: initializing the model

# ## Step 4: populating it with agents

# ## Step 4: scheduler and RNG


# ## Step 4: making the initialization a keyword-based function

# TODO:
# This ties well with stuff like paramscan or automatic parallelizatioln

# It is recommended to initialize agents with
# [`add_agent!`](@ref), instead of manually creating them by calling their type.
# as we did in Step 2 for the `example_agent`.
# This is because allowing Agents.jl to take care of setting the agent IDs leads
# to performance optimizations and guaranteed correctness of the simulation.


# ## Multiple agent types

# Finally, for models where multiple agent types are needed,
# the [`@multiagent`](@ref) macro could be used to improve the performance of the simulation.
#
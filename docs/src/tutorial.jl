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
#   The exact way one defines the evolution rules depends on the type of `AgentBasedModel`
#   used. Agents.jl allows simulations in both discrete time via [`StandardABM`](@ref)
#   as well as continuous time via [`EventQueueABM`](@ref). In this tutorial we will
#   learn the discrete-time version. See the [rock-paper-scissors](@ref eventbased_tutorial)
#   example for an introduction to the continuous time version. For the discrete time version
#   (this tutorial) the evolution rule needs to be provided as at least one, or at most
#   two functions: an agent stepping function, that acts on each agent one by one, and/or
#   a model stepping function, that steps the entire model as a whole.
#   These functions are standard Julia functions that take advantage of the Agents.jl [API](@ref).
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

# ## Step 1: Creating the space

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

# ## Time evolution

# This tutorial utilizes a standard version of ABMs
# During the simulation, the model evolves in discrete steps. During one step, the user
# decides which agents will act, how they will act, how many times, and whether any
# model-level properties will be adjusted.
# Once the time evolution is defined, collecting data during time evolution is
# straightforward by simply stating which data should be collected.


# ## 4. The `AgentBasedModel`


# ## 4.1 Applying it to Schelling
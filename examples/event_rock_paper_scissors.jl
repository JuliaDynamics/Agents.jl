# # [Spatial rock-paper-scissors (event based)](@id eventbased_tutorial)

# ```@raw html
# <video width="auto" controls autoplay loop>
# <source src="../rps_eventqueue.mp4" type="video/mp4">
# </video>
# ```

# This is an introductory example. Similarly to
# Schelling's segregation model of the main [Tutorial](@ref), its goal is to provide a tutorial
# for the [`EventQueueABM`](@ref) instead of the [`StandardABM`](@ref).
# It assumes that you have gone through the [Tutorial](@ref) first.

# The spatial rock-paper-scissors (RPS) is an ABM with the following rules:

# * Agents can be any of three "kinds": Rock, Paper, or Scissors.
# * Agents live in a 2D periodic grid space allowing only one
#   agent per cell.
# * When an agent activates, it can do one of three actions:
#   1. Attack: choose a random nearby agent and attack it.
#      If the agent loses the RPS game it gets removed.
#   1. Move: choose a random nearby position. If it is empty move
#      to it, otherwise swap positions with the agent there.
#   1. Reproduce: choose a random empty nearby position (if any exist).
#      Generate there a new agent of the same type.

# And that's it really!
# However, we want to model this ABM as an event-based model.
# This means that these three actions are independent events
# that will get added to a queue of events.
# We will address this in a moment. For now, let's just make
# functions that represent the actions of the events.

# ## Defining the event functions

# We start by loading `Agents`

using Agents

# and defining the three agent types using [`multiagent`](@ref)
# (see the main [Tutorial](@ref) if you are unfamiliar with [`@multiagent`](@ref)).

@multiagent struct RPS(GridAgent{2})
    @subagent struct Rock end
    @subagent struct Paper end
    @subagent struct Scissors end
end

# %% #src

# Actions of events are standard Julia functions that utilize Agents.jl [API](@ref),
# exactly like those given as
# `agent_step!` in [`StandardABM`](@ref). They act on an agent
# and take the model as the second input and end with an empty `return` statement
# (as their return value is not utilized by Agents.jl).

# The first action is the attack:

function attack!(agent, model)
    ## Randomly pick a nearby agent
    contender = random_nearby_agent(agent, model)
    ## do nothing if there isn't anyone nearby
    isnothing(contender) && return
    ## else perform standard rock paper scissors logic
    ## and remove the contender if you win.
    attack!(agent, contender)
    return
end

# for the attack!(agent, contender) function we could either use some
# branches based on the values of `kindof`

function attack(agent::RPS, contender::RPS)
    kind = kindof(agent)
    kindc = kindof(contender)
    if kind === :Rock && kindc === :Scissors
        remove_agent!(contender, model)
    elseif kind === :Scissors && kindc === :Paper
        remove_agent!(contender, model)
    elseif kind === :Paper && kindc === :Rock
        remove_agent!(contender, model)
    end
end

# or use the @pattern macro for convenience

@pattern attack!(::RPS, ::RPS) = nothing
@pattern attack!(::Rock, contender::Scissors) = remove_agent!(contender, model)
@pattern attack!(::Scissors, contender::Paper) = remove_agent!(contender, model)
@pattern attack!(::Paper, contender::Rock) = remove_agent!(contender, model)

# The movement function is equally simple due to
# the many functions offered by Agents.jl [API](@ref).

function move!(agent, model)
    rand_pos = random_nearby_position(agent.pos, model)
    if isempty(rand_pos, model)
        move_agent!(agent, rand_pos, model)
    else
        occupant_id = id_in_position(rand_pos, model)
        occupant = model[occupant_id]
        swap_agents!(agent, occupant, model)
    end
    return
end

# The reproduction function is the simplest one.

function reproduce!(agent, model)
    pos = random_nearby_position(agent, model, 1, pos -> isempty(pos, model))
    isnothing(pos) && return
    ## pass target position as a keyword argument
    replicate!(agent, model; pos)
    return
end

## Defining the propensity and timing of the events

# Besides the actual event action defined as the above functions,
# there are two more pieces of information necessary:
# 1) how likely an event is to happen, and
# 2) how long after the previous event it will happen.

# Now, in the "Gillespie" type of simulations, these two things coincide:
# The probability for an event is its relative propensity (rate), and the time
# you have to wait for it to happen is inversely the propensity (rate).
# When creating an `AgentEvent` (see below), the user has the option to
# go along this "Gillespie" route, which is the default.
# However, the user can also have more control by explicitly providing a function
# that returns the time until an event triggers
# (by default this function becomes a random sample of an exponential distribution).

# Let's make this concrete. For all events we need to define their propensities.
# Another way to think of propensities is the relative probability mass
# for an event to happen.
# The propensities may be constants or functions of the
# currently actived agent and the model.

# Here, the propensities for moving and attacking will be constants,
attack_propensity = 1.0
movement_propensity = 0.5

# while the propensity for reproduction will be a function modelling
# "seasonality", so that willingness to reproduce goes up and down periodically
function reproduction_propensity(agent, model)
    return cos(abmtime(model))^2
end

## Creating the `AgentEvent` structures

# Events are registered as an [`AgentEvent`](@ref), then are added into a container,
# and then given to the [`EventQueueABM`](@ref).
# The attack and reproduction events affect all agents,
# and hence we don't need to specify what agents they apply to.

attack_event = AgentEvent(action! = attack!, propensity = attack_propensity)

reproduction_event = AgentEvent(action! = reproduce!, propensity = reproduction_propensity)

# The movement event does not apply to rocks however,
# so we need to specify the agent "kinds" that it applies to,
# which is `(:Scissors, :Paper)`.
# Additionally, we would like to change how the timing of the movement events works.
# We want to change it from an exponential distribution sample to something else.
# This "something else" is once again an arbitrary Julia function,
# and for here we will make:
function movement_time(agent, model, propensity)
    ## `agent` is the agent the event will be applied to,
    ## which we do not use in this function!
    t = 0.1 * randn(abmrng(model)) + 1
    return clamp(t, 0, Inf)
end

# And with this we can now create

movement_event = AgentEvent(
    action! = move!, propensity = movement_propensity,
    kinds = (:Scissors, :Paper), timing = movement_time
)

# we wrap all events in a tuple and we are done with the setting up part!

events = (attack_event, reproduction_event, movement_event)

# ## Creating and populating the `EventQueueABM`

# This step is almost identical to making a [`StandardABM`](@ref) in the main [Tutorial](@ref).
# We create an instance of [`EventQueueABM`](@ref) by giving it the agent type it will
# have, the events, and a space (optionally, defaults to no space).
# Here we have

space = GridSpaceSingle((100, 100))

using Random: Xoshiro
rng = Xoshiro(42)

model = EventQueueABM(RPS, events, space; rng, warn = false)

# populating the model with agents is the same as in the main [Tutorial](@ref),
# using the [`add_agent!`](@ref) function.
# By default, when an agent is added to the model
# an event is also generated for it and added to the queue.

for p in positions(model)
    type = rand(abmrng(model), (Rock, Paper, Scissors))
    add_agent!(p, type, model)
end

# We can see the list of scheduled events via

abmqueue(model)

# Here the queue maps pairs of (agent id, event index) to the time
# the events will trigger.
# There are currently as many scheduled events because as the amount
# of agents we added to the model.
# Note that the timing of the events
# has been rounded for display reasons!

# Now, as per-usual in Agents.jl we are making a keyword-based function
# for constructing the model, so that it is easier to handle later.

function initialize_rps(; n = 100, nx = n, ny = n, seed = 42)
    space = GridSpaceSingle((nx, ny))
    rng = Xoshiro(seed)
    model = EventQueueABM(RPS, events, space; rng, warn = false)
    for p in positions(model)
        type = rand(abmrng(model), (Rock, Paper, Scissors))
        add_agent!(p, type, model)
    end
    return model
end

# ## Time evolution
# %% #src

# Time evolution for [`EventBasedABM`](@ref) is identical
# to that of [`StandardABM`](@ref), but time is continuous.
# So, when calling `step!` we pass in a real time.

step!(model, 123.456)

nagents(model)

# Alternatively we could give a function for when to terminate the time evolution.
# For example, we terminate if any of the three types of agents become less
# than a threshold

function terminate(model, t)
    kinds = allkinds(RPS)
    threshold = 1000
    ## Alright, this code snippet loops over all kinds,
    ## and for each it checks if it is less than the threshold.
    ## if any is, it returns `true`, otherwise `false.`
    logic = any(kinds) do kind
        n = count(a -> kindof(a) == kind, allagents(model))
        return n < threshold
    end
    ## For safety, in case this never happens, we also add a trigger
    ## regarding the total evolution time
    return logic || (t > 1000.0)
end

step!(model, terminate)

abmtime(model)

# ## Data collection
# %% #src

# The entirety of the Agents.jl [API](@ref) is orthogonal/agnostic to what
# model we have. This means that whatever we do, plotting, data collection, etc.,
# has identical syntax irrespectively of whether we have a `StandardABM` or `EventQueueABM`.

# Hence, data collection also works almost identically to [`StandardABM`](@ref).

# Here we will simply collect the number of each agent kind.

model = initialize_rps()

adata = [(a -> kindof(a) === X, count) for X in allkinds(RPS)]

adf, mdf = run!(model, 100.0; adata, when = 0.5, dt = 0.01)

adf[1:10, :]

# Let's visualize the population sizes versus time:

using Agents.DataFrames
using CairoMakie

tvec = adf[!, :time]
populations = adf[:, Not(:time)]
alabels = ["rocks", "papers", "scissors"]

fig = Figure();
ax = Axis(fig[1,1]; xlabel = "time", ylabel = "population")
for (i, l) in enumerate(alabels)
    lines!(ax, tvec, populations[!, i]; label = l)
end
axislegend(ax)
fig

# ## Visualization

# Visualization for [`EventQueueABM`](@ref) is identical to that for [`StandardABM`](@ref)
# that we learned in the [visualization tutorial](@ref vis_tutorial).
# Naturally, for `EventQueueABM` the `dt` argument of [`abmvideo`](@ref)
# corresponds to continuous time and does not have to be an integer.

const colormap = Dict(:Rock => "black", :Scissors => "gray", :Paper => "orange")
agent_color(agent) = colormap[kindof(agent)]
plotkw = (agent_color, agent_marker = :rect, agent_size = 5)
fig, ax, abmobs = abmplot(model; plotkw...)

fig

#

model = initialize_rps()
abmvideo("rps_eventqueue.mp4", model;
    dt = 0.5, frames = 300,
    title = "Rock Paper Scissors (event based)", plotkw...,
)

# ```@raw html
# <video width="auto" controls autoplay loop>
# <source src="../rps_eventqueue.mp4" type="video/mp4">
# </video>
# ```

# We see model dynamics similar to Schelling's segregation model:
# neighborhoods for same-type agents form! But they are not static,
# but rather expand and contract over time!

# We could explore this interactively by launching the interactive GUI
# with the [`abmexploration`](@ref) function!

# Let's first define the data we want to visualize, which in this
# case is just the count of each agent kind

model = initialize_rps()
fig, abmobs = abmexploration(model; adata, alabels, when = 0.5, plotkw...)
fig

# We can then step the observable and see the updates in the plot:
for _ in 1:100 # this loop simulates pressing the `run!` button
    step!(abmobs, 1.0)
end

fig

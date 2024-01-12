# [Spatial rock-paper-scissors (event based)](@id eventbased_tutorial)

# This is an introductory example. Similarly to
# [Schelling's segregation model](@ref), its goal is to provide a tutorial
# but for the [`EventQueueABM`](@ref) instead of the [`StandardABM`](@ref).
# It assumes that you have gone through both the [Tutorial](@ref) and
# the [Schelling's segregation model](@ref) example.

# The spatial rock-paper-scissors (RPS) is an ABM with the following rules:

# * Agents can be any of three types: Rock, Paper, or Scissors.
# * Agents live in a 2D periodic grid space allowing only one
#   agent per cell.
# * When an agent activates, it can do one of three actions:
#   1. Attack: choose a random nearby agent and attack it.
#      If the agent loses the RPS game it gets removed.
#   1. Move: choose a random nearby position. If it is empty move
#      to it, otherwise swap positions with the agent there.
#   1. Reproduce: choose a random empty nearby position (if any).
#      Generate there a new agent of the same type.

# And that's it really!
# However, we want to model this ABM as an event-based model.
# This means that these three actions are independent events
# that will get added to a queue of events.
# We will address this in a moment. For now, let's just make
# functions that represent the actions of the events.

# ## Defining the event functions

# We start by loading `Agents`

using Agents, Random

# and defining the three agent types
@agent struct Rock(GridAgent{2}) end
@agent struct Paper(GridAgent{2}) end
@agent struct Scissors(GridAgent{2}) end

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
    ## and remove the contender if you win
    if agent isa Rock && contender isa Scissors
        remove_agent!(contender, model)
    elseif agent isa Scissors && contender isa Paper
        remove_agent!(contender, model)
    elseif agent isa Paper && contender isa Rock
        remove_agent!(contender, model)
    end
    return
end

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
    add_agent!(pos, typeof(agent), model)
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

# while the propensity for reproduction will be a function
function reproduction_propensity(agent, model)
    return (1/2) ^ ceil(Int, abmtime(model))
end

## Creating the `AgentEvent` structures

# Events are registered as an [`AgentEvent`](@ref), then are added into a container,
# and then given to the [`EventQueueABM`](@ref).
# The attack and reproduction events affect all agents,
# and hence we don't need to specify an agent type that this event
# applies to, leaving the `AbstractAgent` as the default.

attack_event = AgentEvent(action! = attack!, propensity = attack_propensity)

reproduction_event = AgentEvent(action! = reproduce!, propensity = reproduction_propensity)

# The movement event does not apply to rocks however,
# so we need to specify the agent super type that it applies to,
# which is `Union{Scissors, Paper}`.
# Additionally, we would like to change how the timing of the movement events works.
# We want to change it from an exponential distribution sample to something else.
# This "something else" is once again an arbitrary Julia function,
# and for here we will make:
function movement_time(agent, model, propensity)
    # `agent` is the agent the event will be applied to,
    # which we do not use in this function!
    t = 0.1 * randn(abmrng(model)) + 1
    return clamp(t, 0, Inf)
end

# And with this we can now create

movement_event = AgentEvent(
    action! = move!, propensity = movement_propensity,
    types = Union{Scissors, Paper}, timing = movement_time
)

# we wrap all events in a tuple and we are done with the setting up part!

events = (attack_event, reproduction_event, movement_event)

# ## Creating and populating the `EventQueueABM`

# This step is almost identical to making a [`StandardABM`](@ref) in the main [Tutorial](@ref).
# We create an instance of [`EventQueueABM`](@ref) by giving it the agent types it will
# have, the events vector, and a space (optionally, defaults to no space).
# Here we have

space = GridSpaceSingle((100, 100))

rng = Xoshiro(42)
AgentTypes = Union{Rock, Paper, Scissors}
model = EventQueueABM(AgentTypes, events, space; rng, warn = false)

# populating the model with agents is as in the main [Tutorial](@ref),
# using the [`add_agent!`](@ref) function. The only difference here
# is that (by default), when an agent is added to the model, the
# an event is generated for it and added to the queue.

for p in positions(model)
    type = rand(abmrng(model), (Rock, Paper, Scissors))
    add_agent!(p, type, model)
end

using CairoMakie
function dummyplot(model)
    fig = Figure()
    ax = Axis(fig[1,1])
    alla = allagents(model)
    colormap = Dict(Rock => "black", Scissors => "gray", Paper => "orange")
    pos = [a.pos for a in alla]
    color = [colormap[typeof(a)] for a in alla]
    scatter!(ax, pos; color, markersize = 10)
    return fig
end

dummyplot(model)

# ## Time evolution
# %% #src

# Time evolution for [`EventBasedABM`](@ref) is identical
# to that of [`StandardABM`](@ref), but time is continuous.
# So, when calling `step!` we pass in a real time.

step!(model, 1.0)

# Alternatively we could give a function for when to terminate the time evolution.

# ## Data collection

# Data collection also works almost identically to [`StandardABM`](@ref).

# Here we will simply collect the number of each agent type.
adata = [(a -> a isa X, count) for X in (Rock, Paper, Scissors)]

run!(model, 10.0; adata, when = 0.2)
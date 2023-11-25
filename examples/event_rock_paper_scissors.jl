# [Spatial rock-paper-scissors (event based)](@id eventbased_simple)

using Agents, Random

# define the three agent types
@agent struct Rock(GridAgent{2}) end
@agent struct Paper(GridAgent{2}) end
@agent struct Scissors(GridAgent{2}) end

# ## Defining the event functions

# Events are standard Julia functions that utilize Agents.jl [API](@ref),
# exactly like those given as
# `agent_step!` in [`StandardABM`](@ref). They act on an agent
# and take the model as the second input and end with an empty `return` statement
# (as their return value is not utilized by Agents.jl).

function attack!(agent, model)
    contender = random_nearby_agent(agent, model)
    # do nothing if there isn't anyone nearby
    isnothing(contender) && return
    # else perform standard rock paper scissors logic
    if agent isa Rock && contender isa Scissors
        remove_agent!(contender, model)
    elseif agent isa Scissors && contender isa Paper
        remove_agent!(contender, model)
    elseif agent isa Paper && contender isa Rock
        remove_agent!(contender, model)
    end
    return
end

function reproduce!(agent, model)
    pos = random_nearby_position(agent, model, 1, pos -> isempty(pos, model))
    isnothing(pos) && return
    add_agent!(pos, typeof(agent), model)
    return
end

function move!(agent, model)
    rand_pos = random_nearby_position(agent.pos, model)
    if isempty(rand_pos, model)
        move_agent!(agent, rand_pos, model)
    else
        near = model[id_in_position(rand_pos, model)]
        swap_agents!(agent, near, model)
    end
    return
end

## Defining the propensity and timing of the events

# Besides the actual event action defined as the above functions,
# there are two more pieces of information necessary:
# 1) how likely an event is to happen, and
# 2) how long after the previous event it will happen.

# Now, in the "Gillespie" type of simulations, these two things coincide:
# The probability for an event is it's relative rate, and the time
# you have to wait for it to happen is inversely the rate.
# When creating an `AgentEvent` (see below), the user has the option to
# go along this "Gillespie" route, which is the default.
# However, the user can also have more control by explicitly providing a function
# that returns the time until an event triggers
# (by default this function becomes a random sample of an exponential distribution)

# Let's make this concrete. For all events we need to define their propensities.
# Another way to think of propensities is the relative probability mass
# for an event to happen.
# The propensities may be constants or functions of the
# currently actived agent and the model.
# Here, the propensities for movement and battling will be constants,

attack_propensity = 1.0
movement_propensity = 0.5

# while the propensity for reproduction will be proportional
# to the population size of the agent

function reproduction_propensity(agent, model)
    same = count(a -> a isa typeof(agent), allagents(model))
    return 2*same/nagents(model)
end

## Creating the `AgentEvent` structures

# Events are registered as `AgentEvent`, are put into a vector
# and then given to the `EventQueueABM`.
# The attack and reproduction events affect all agents,
# and hence we don't need to specify an agent type that this event
# applies to, leaving the `AbstractAgent` as the default.

attack_event = AgentEvent(attack!, attack_propensity)

reproduction_event = AgentEvent(reproduce!, reproduction_propensity)

# The movement event does not apply to rocks however,
# so we need to specify the agent super type that it applies to,
# which is `Union{Scissors, Paper}`.
# Additionally, we would like to change how the timing of the movement events works.
# We want to change it from an exponential distribution sample to something else.
# This "something else" is once again an arbitrary Julia function,
# and for here we will make:

function movement_time(agent, model) # `agent` is the agent the event will be applied to!
    t = randn(abmrng(model)) + 3
    return clamp(t, 0, Inf)
end

# And with this we can now create
movement_event = AgentEvent(move!, movement_propensity, Union{Scissors, Paper}, movement_time)

# we wrap all events in a tuple and we are done with the setting up part!

events = (attack_event, reproduction_event, movement_event)

# ## Creating and populating the `EventQueueABM`

# This step is almost identical to making a [`StandardABM`](@ref) in the main [Tutorial](@ref).
# We create an instance of [`EventQueueABM`](@ref) by giving it the agent types it will
# have, the events vector, and a space (optionally, defaults to no space).
# Here we have

space = GridSpaceSingle((10, 10))

rng = Xoshiro(42)
model = EventQueueABM(Union{Rock, Paper, Scissors}, events, space; rng)

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
    colormap = Dict(Rock => "black", Scissors => "gray", paper => "orange")
    pos = [a.pos for a in alla]
    color = [colormap[typeof(a)] for a in alla]
    scatter!(ax, pos; color)
    return fig
end

dummyplot(model)

# TODO: Stepping;

# %% #src

step!(model, 1.32)

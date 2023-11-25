export EventQueueABM, AgentEvent
export abmqueue, abmevents, abmtime, add_event!

"""
    AgentEvent(action!, propensity [, Types] [, timing])

An event type that will be given to [`EventQeueABM`](@ref).
`action!` is the function `action!(agent, model)` that will
act on the agent the event corresponds to.
`propensity` is either a constant real number,
or a function `propensity(model, agent)` that returns
the propensity of the event. A different way to think
of the propensity is a "probability mass".

Two optional arguments are possible:

- `Types` is the supertype of agents that this event is applicable to.
  It defaults to `AbstractAgent`.
- `timing` can be a function `timing(agent, model)`, which will return
  the time will event trigger (the time relative to its creation time).
  By default it is `nothing`, which means that the time is a randomly
  sampled time from an exponential distribution with parameter the
  total propensity of all applicable events to the agent.
  I.e., by default the "Gillespie" algorithm is used to time the events.
"""
struct AgentEvent{F<:Function, P, A<:Type, T}
    action!::F
    propensity::P
    types::A
    timing::T
end
# Convenience:
AgentEvent(action!, propensity) = AgentEvent(action!, propensity, AbstractAgent, nothing)
AgentEvent(action!, propensity, A::Type) = AgentEvent(action!, propensity, A, nothing)
AgentEvent(action!, propensity, timing::Union{Nothing, Function}) =
AgentEvent(action!, propensity, AbstractAgent, timing)

using DataStructures: PriorityQueue

struct EventQueueABM{
    S<:SpaceType,
    A<:AbstractAgent,
    C<:ContainerType{A},
    P,E,R<:AbstractRNG} <: AgentBasedModel{S}
    time::Base.RefValue{Float64}
    agents::C
    space::S
    properties::P
    rng::R
    maxid::Base.RefValue{Int64}
    # TODO: Test whether making the `events` a `Vector` has any difference in performance
    events::E
    # Dummy vector that is used to calculate next event
    propensities::Vector{Float64}
    # maps an agent type to its applicable events
    event_queue::PriorityQueue{Tuple{Int, Int}, Float64}
end

"""
    EventQueueABM <: AgentBasedModel

A concrete implementation of an [`AgentBasedModel`](@ref) which operates in
continuous time, in contrast with the discrete nature of [`StandardABM`](@ref).
Here is a summary of how the time evolution of this model works:

A list of possible events that can be created is provided to the model.
The events have four pieces of information:

1. The action that they perform once triggered. The action is a generic Julia function
   `action!(agent, model)` that will act on the agent correspond to the event.
   Similarly with `agent_step!` for [`StandardABM`](@ref), this function may do anything
   and utilize any function from the Agents.jl [API](@ref) or the entire Julia ecosystem.
   The `action!` function may spawn new events by using the [`add_event!`](@ref) function,
   although there is also a default behavior that spawns new events automatically.
2. The propensity of the event. A propensity is a concept similar to a probability mass.
   When generating a new event for an agent, first all applicable events for that agent
   are collected. Then, their propensities are calculated. The event generated then
   is selected randomly weighted by the propensity of each event.
3. The agent type(s) the event applies to. By default it applies to all types.
4. The timing of the event, i.e., when should it be triggered once it is generated.
   By default this is an exponentially distributed random variable multiplied by the
   sum of calculated propensities.

Events are scheduled in a temporally ordered queue, and once
the model evolution time reaches the event time, the event is "triggered".
This means that first the event action is performed on its corresponding agent.
By default, once an event has finished its action,
a new event is generated for the same agent (if the agent still exists), chosen randomly
based on the propensities as discussed above. Then a time for the new event
is generated and the new event is added back to the queue.
In this way, an event always generates a new event after it has finished its action
(by default; can be overwritten).

`EventQueueABM` is a generalization of "Gillespie"-like simulations, offering
more power and flexibility than a standard Gillespie simulation,
while also allowing "Gillespie"-like configuration with the default settings.

Here is how to construct an `EventQueueABM`:

    EventQueueABM(AgentTypes, events [, space]; kwargs...)

Create an instance of an [`EventQueueABM`](@ref).
`AgentTypes, space` are exactly as in [`StandardABM`](@ref).
`events` is a tuple of instances of [`AgentEvent`](@ref), which contain the four
pieces of information referenced above.

By default, each time a new agent is added to the model via [`add_agent!`](@ref), a new
event is generated based on the pool of possible events that can affect the agent.
In this way the simulation can immediatelly start once agents have been added to the model.

You can disable this behavior with a keyword. In this case, you need to manually use
the function [`add_event!`](@ref) within the event `action!` functions
to add new events to the queue.
(you can always use this function regardless of the default event scheduling behavior)

## Keywords
- `container, properties, rng, warn`: same as in [`StandardABM`](@ref).
- `autogenerate_on_add::Bool = true`: whether to automatically generate a new event for
  an agent when the agent is added to the model.
- `autogenerate_after_action::Bool = true`: whether to automatically generate a new
  event for an agent after an event affected said agent has been triggered.
"""
function EventQueueABM(
    ::Type{A}, events::E,
    space::S = nothing;
    container::Type = Dict{Int},
    properties::P = nothing,
    rng::R = Random.default_rng(),
    warn = true,
) where {A<:AbstractAgent,S<:SpaceType,E,P,R<:AbstractRNG}
    agent_validator(A, space, warn)
    C = construct_agent_container(container, A)
    agents = C()
    # The queue stores references to events;
    # the reference is two integers; one is the agent ID
    # and the other is the index of the event in `events`
    queue = PriorityQueue{Tuple{Int, Int}, Float64}()
    propensities = zeros(length(events))
    return EventQueueABM{S,A,C,P,E,R}(
        Ref(0.0), agents, space, properties, rng,
        Ref(0), events, propensities, queue
    )
end

# standard accessors
"""
    abmqueue(model::EventQueueABM)

Return the queue of scheduled events in the `model`.
The queue maps two integers (agent id, event index) to
the time the event will occur, in absolute time.
"""
abmqueue(model::EventQueueABM) = getfield(model, :event_queue)

"""
    abmevents(model::EventQueueABM)

Return all possible events stored in the model.
"""
abmevents(model::EventQueueABM) = getfield(model, :events)

"""
    abmtime(model::AgentBasedModel)

Return the current time of the model.
All models are initialized at time 0.
"""
abmtime(model::EventQueueABM) = getfield(model, :time)[]

containertype(::EventQueueABM{S,A,C}) where {S,A,C} = C
agenttype(::EventQueueABM{S,A}) where {S,A} = A

###########################################################################################
# %% Adding events to the queue
###########################################################################################
# This function ensures that once an agent is added into the model,
# an event is created and added for it. It is called internally
# by `add_agent_to_model!`.
function extra_actions_after_add!(agent, model::EventQueueABM)
    generate_event_in_queue!(agent, model)
end

# This is the main function that is called in `step!`
# after the other main function `process_event!` is
# done
function generate_event_in_queue!(agent, model)
    # First, update propensities vector
    events = abmevents(model)
    # this is the dummy propensities vector that
    # has the same indices as the model events
    propensities = getfield(model, :propensities)
    for (i, event) in enumerate(events)
        # TODO: This check can be optimized;
        # instead of checking every time if an agent is a subtype,
        # we can check this once in the model generation
        # and store a vector with indices of valid events and use that.
        if agent isa event.types
            p = obtain_propensity(event, agent, model)
        else
            p = 0.0
        end
        propensities[i] = p
    end
    # Then, select an event based on propensities
    event_idx, totalprop = sample_propensity(abmrng(model), propensities)
    # The time to the event is generated from the selected event
    selected_event = abmevents(model)[event_idx]
    t = generate_time_of_event(selected_event, totalprop, agent, model)
    add_event!(agent, event_idx, t, model)
end

function obtain_propensity(event::AgentEvent, agent, model)
    if event.propensity isa Real
        return event.propensity
    else
        p = event.propensity(agent, model)
        return p
    end
end

# from StatsBase.jl
function sample_propensity(rng, wv)
    totalprop = sum(wv)
    t = rand(rng) * totalprop
    i = 1
    cw = wv[1]
    while cw < t && i < length(wv)
        i += 1
        @inbounds cw += wv[i]
    end
    return i, totalprop
end

function generate_time_of_event(event, totalprop, agent, model)
    if isnothing(event.timing)
        t = randexp(abmrng(model)) * totalprop
    else
        t = event.timing(agent, model)
    end
    return t
end

"""
    add_event!(agent, event_idx::Int, t::Real, model::EventQueueABM)

Add a new event to the queue to be triggered for `agent`, based on the index of the
event (from the list of events). The event will trigger in `t` time _from_ the
current time of the `model`.
"""
function add_event!(agent::AbstractAgent, event_idx::Int, t::Real, model::EventQueueABM)
    enqueue!(abmqueue(model), (agent.id, event_idx) => t + abmtime(model))
    return
end
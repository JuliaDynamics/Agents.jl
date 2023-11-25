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

Pairs composed of an event and an agent are scheduled at some particular time,
and once the model time reaches that time, the event is executed on the agent.

Events must be passed during initialization of the model with the `all_events` keywords;
they are arbitrary agent stepping functions analogous to the `agent_step!` function used
currently in the [`StandardABM`](@ref) implementation. Hence, events have access to the
full API of `Agents.jl`.

Events that are occurring are chosen randomly during scheduling, based on the Direct Method
of the [Gillespie Algorithm](https://en.wikipedia.org/wiki/Gillespie_algorithm). Each event
has a possible propensity value and the probability for choosing a particular event is
proportional to the propensity. During the model time evolution, two things occur:

- the model time reaches the time of the next scheduled event and the event action
  is performed on the paired agent;
- the scheduler generates a new event utilizing the rates corresponding to the agent type,
  and schedules it together with the same paired agent;

Even if the scheduler automatically generates new events based on the rates, it should be
initialized by adding some events at the start of the simulation through the [`add_event!`](@ref)
function.

## Keywords

- `all_events`:
- `all_rates`:
- `container, properties, scheduler, rng, warn` work the same way as in a [`StandardABM`](@ref).
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
The que maps two integers (agent id, event index) to
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
    # add the event in the queue!
    enqueue!(abmqueue(model), (agent.id, event_idx) => t + abmtime(model))
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

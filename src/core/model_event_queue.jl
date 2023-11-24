export EventQueueABM, AgentEvent
export abmrates, abmevents, abmtime, add_event!

struct AgentEvent{F<:Function, P, A<:Type, T}
    action!::F
    propensity::P
    types::A
    timing::T
end
# Convenience:
AgentEvent(action!, propensity) = AgentEvent(action!, propensity, AbstractAgent, nothing)
AgentEvent(action!, propensity, A::Type) = AgentEvent(action!, propensity, A, nothing)
AgentEvent(action!, prop::Union{Nothing, Function}) =
AgentEvent(action!, propensity, AbstractAgent, prop)

struct Event
    id::Int
    event_idx::F # index of the tuple of events
end

using DataStructures: PriorityQueue

struct EventQueueABM{
    S<:SpaceType,
    A<:AbstractAgent,
    C<:ContainerType{A},
    T,F,P,E,L,R<:AbstractRNG} <: AgentBasedModel{S}
    time::Base.RefValue{Float64}
    agents::C
    space::S
    scheduler::F
    properties::P
    rng::R
    maxid::Base.RefValue{Int64}
    agents_types::T
    # TODO: Test whether making the `events` a `Vector` has any difference in performance
    events::E
    event_queue::PriorityQueue{Event, Float64}
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
    ::Type{A}, events,
    space::S = nothing;
    container::Type = Dict{Int},
    scheduler::F = Schedulers.fastest,
    properties::P = nothing,
    rng::R = Random.default_rng(),
    warn = true,
) where {A<:AbstractAgent,S<:SpaceType,F,P,R<:AbstractRNG,W,L}
    agent_validator(A, space, warn)
    C = construct_agent_container(container, A)
    agents = C()
    agents_types = union_types(A)
    T = typeof(agents_types)
    queue = PriorityQueue{Event, Float64}()
    return EventQueueABM{S,A,C,T,F,P,W,L,R}(Ref(0.0), agents, space, scheduler, properties, rng,
                                            Ref(0), agents_types, events, queue)
end

"""
    abmqueue(model::EventQueueABM)
"""
abmqueue(model::EventQueueABM) = getfield(model, :event_queue)

"""
    abmevents(model::EventQueueABM)
"""
abmevents(model::EventQueueABM) = getfield(model, :all_events)
function abmevents(agent, model::EventQueueABM)
    agent_type = findfirst(isequal(typeof(agent)), tuple_agenttype(model))
    return abmevents(model)[agent_type]
end

"""
    abmrates(model::EventQueueABM)
"""
abmrates(model::EventQueueABM) = getfield(model, :all_rates)
function abmrates(agent, model::EventQueueABM)
    agent_type = findfirst(isequal(typeof(agent)), tuple_agenttype(model))
    rates = abmrates(model)[agent_type]
    return map(r -> r isa Function ? r(model) : r, rates)
end

"""
    add_event!(agent, event, t, model::EventQueueABM)
"""
function add_event!(agent::AbstractAgent, event, t, model)
    id = agent.id
    event_idx = findfirst(isequal(event), abmevents(model[id], model))
    return add_event!(id, event_idx, t, model)
end
function add_event!(id, event_idx, t, model)
    queue = abmqueue(model)
    enqueue!(queue, Event(id, event_idx) => t)
end

"""
    abmtime(model::EventQueueABM)
"""
abmtime(model::EventQueueABM) = getfield(model, :time)[]

containertype(::EventQueueABM{S,A,C}) where {S,A,C} = C
agenttype(::EventQueueABM{S,A}) where {S,A} = A
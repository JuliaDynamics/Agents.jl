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
    # maps an agent type to its applicable events
    # The "type" is the symbol `nameof(typeof(agent))`
    applicable_events::Dict{Symbol, Vector{Int}}
    # TODO: The value type of the vector shouldn't be limited
    propensities_vectors::Dict{Symbol, Vector{Float64}}
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
    agents_types = union_types(A)
    T = typeof(agents_types)
    queue = PriorityQueue{Event, Float64}()
    # Create the applicable events
    applicable_events = Dict{Symbol, Vector{Int}}()
    propensities_vectors = Dict{Symbol, Vector{Float64}}()
    for at in agents_types
        applicable = [i for i in eachindex(events) if at <: (events[i].types)]
        applicable_events[nameof(at)] = applicable
        propensities_vectors[nameof(at)] = zeros(length(applicable))
    end

    return EventQueueABM{S,A,C,T,F,P,W,L,R}(
        Ref(0.0), agents, space, scheduler, properties, rng,
        Ref(0), agents_types, events, applicable_events, propensities_vectors, queue
    )
end

# This function ensures that once an agent is added into the model,
# an event is created and added for it. It is called internally
# by `add_agent_to_model!`.
function extra_actions_after_add!(agent, model::EventQueueABM)
    generate_event_in_queue!(agent, model)
end

# This is the main function that is called in `step!`:
function generate_event_in_queue!(agent, model)
    # First, update propensities vector
    propensities = getfield(model, :propensities)
    for (i, event) in enumerate(getfield(model, :events))
        if agent isa event.Types
            p = obtain_propensity(event, agent, model)
        else
            p = 0.0
        end
        propensities[i] = p
    end
    # Then, select an event based on propensities
    event_idx, totalprop = sample_propensity(abmrng(model), propensities)
    # The time to the event is generated from the selected event
    t = generate_time_of_event(event, totalprop, agent, model)
    # add the event in the queue!
    enqueue!(abmqueue(model), Event(id, event_idx) => t + abmtime(model))
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
    if isnothing(event.propensity)
        t = randexp(abmrng(model)) * totalprop
    else
        t = event.propensity(agent, model)
    end
    return t
end

"""
    abmqueue(model::EventQueueABM)

Return the queue of scheduled events in the `model`.
"""
abmqueue(model::EventQueueABM) = getfield(model, :event_queue)

"""
    abmtime(model::AgentBasedModel)

Return the current time of the model.
"""
abmtime(model::EventQueueABM) = getfield(model, :time)[]

containertype(::EventQueueABM{S,A,C}) where {S,A,C} = C
agenttype(::EventQueueABM{S,A}) where {S,A} = A

export EventQueueABM
export abmqueue, abmrates, abmevents, add_event!

using DataStructures: PriorityQueue

struct Event
    id::Int
    event_index::Int
end

struct EventQueueABM{
    S<:SpaceType,
    A<:AbstractAgent,
    C<:ContainerType{A},
    F,P,W,L,R<:AbstractRNG} <: AgentBasedModel{S}
    agents::C
    space::S
    scheduler::F
    properties::P
    rng::R
    maxid::Base.RefValue{Int64}
    agents_first::Bool
    all_events::W
    all_rates::L
    event_queue::PriorityQueue{Event, Float64}
end

function EventQueueABM(
    ::Type{A},
    space::S = nothing;
    container::Type = Dict{Int},
    scheduler::F = Schedulers.fastest,
    properties::P = nothing,
    rng::R = Random.default_rng(),
    warn = true,
    warn_deprecation = true,
    all_events::W = nothing,
    all_rates::L = nothing
) where {A<:AbstractAgent,S<:SpaceType,G,K,F,P,R<:AbstractRNG,W,L}
    agent_validator(A, space, warn)
    C = construct_agent_container(container, A)
    agents = C()
    return EventQueueABM{S,A,C,F,P,W,L,R}(agents, space, scheduler, properties, rng, Ref(0),
                                          all_events, all_rates, PriorityQueue{Event, Float64}())
end

abmqueue(model::EventQueueABM) = getfield(model, :event_queue)

abmevents(model::EventQueueABM) = getfield(model, :all_events)
function abmevents(agent, model::EventQueueABM)
    agent_type = findfirst(isequal(typeof(agent)), union_types(agenttype(model)))
    return abmevents(model)[agent_type]
end

abmrates(model::EventQueueABM) = getfield(model, :all_rates)
function abmrates(agent, model::EventQueueABM)
    agent_type = findfirst(isequal(typeof(agent)), union_types(agenttype(model)))
    return abmrates(model)[agent_type]
end

add_event!(agent::AbstractAgent, event, t, model) = add_event!(agent.id, event, t, model)
function add_event!(id, event, t, model)
    queue = abmqueue(model)
    event_type = findfirst(isequal(event), abmevents(model[id], model))
    enqueue!(queue, Event(id, event_type) => t)
end

agenttype(::EventQueueABM{S,A}) where {S,A} = A
containertype(::EventQueueABM{S,A,C}) where {S,A,C} = C




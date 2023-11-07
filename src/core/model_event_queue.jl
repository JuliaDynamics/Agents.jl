
export EventQueueABM

using DataStructures: PriorityQueue

struct Event
    id::Int
    event_index::Int
end

struct EventQueueABM{
    S<:SpaceType,
    A<:AbstractAgent,
    C<:ContainerType{A},
    G,K,F,P,W,L,R<:AbstractRNG} <: AgentBasedModel{S}
    agents::C
    agent_step::G
    model_step::K
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
    agent_step!::G = dummystep,
    model_step!::K = dummystep,
    container::Type = Dict{Int},
    scheduler::F = Schedulers.fastest,
    properties::P = nothing,
    rng::R = Random.default_rng(),
    agents_first::Bool = true,
    warn = true,
    warn_deprecation = true,
    all_events::W,
    all_rates::L
) where {A<:AbstractAgent,S<:SpaceType,G,K,F,P,R<:AbstractRNG,W,L}
    agent_validator(A, space, warn)
    C = construct_agent_container(container, A)
    agents = C()
    return EventQueueABM{S,A,C,W,L,G,K,F,P,R}(agents, agent_step!, model_step!, space, scheduler,
                                              properties, rng, Ref(0), agents_first, all_events, 
                                              all_rates, PriorityQueue{Event, Float64}())
end

abmqueue(model::EventQueueABM) = getfield(model, :event_queue)
abmevents(model::EventQueueABM) = getfield(model, :all_events)
abmrates(model::EventQueueABM) = getfield(model, :all_rates)

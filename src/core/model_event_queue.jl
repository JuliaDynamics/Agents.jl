export EventQueueABM, AgentEvent
export abmqueue, abmevents, abmtime, add_event!

"""
    AgentEvent(; action!, propensity, types, [timing])

An event instance that can be given to [`EventQeueABM`](@ref).

- `action! = dummystep`: is the function `action!(agent, model)` that will
  act on the agent the event corresponds to. By default it is an action that does nothing.
  The `action!` function may call [`add_event!`](@ref) to generate new events, regardless
  of the automatic generation of events by Agents.jl.
- `propensity = 1.0`: it can be either a constant real number,
  or a function `propensity(agent, model)` that returns the propensity of the event.
- `types = AbstractAgent`: the supertype of agents the `action!` function can be applied to.
- `timing = Agents.exp_propensity`: decides how long after its generation the event should 
  trigger. By default the time is a randomly sampled time from an exponential distribution 
  with parameter the total propensity of all applicable events to the agent.
  I.e., by default the "Gillespie" algorithm is used to time the events.
  Alternatively, it can be a custom function `timing(agent, model, propensity)` 
  which will return the time.

Notice that when using the [`add_event!`](@ref) function, `propensity, timing` are ignored
if `event_idx` and `t` are given.
"""
Base.@kwdef struct AgentEvent{F<:Function, P, A<:Type, T<:Function}
    action!::F = dummystep
    propensity::P = 1.0
    types::A = AbstractAgent
    timing::T = exp_propensity
end

exp_propensity(agent, model, propensity) = randexp(abmrng(model))/propensity

using DataStructures: PriorityQueue

struct EventQueueABM{
    S<:SpaceType,
    A<:AbstractAgent,
    C<:ContainerType{A},
    P,E,R<:AbstractRNG,ET,PT,FPT,TI,Q} <: AgentBasedModel{S}
    agents::C
    space::S
    properties::P
    rng::R
    events::E
    idx_events_each_type::ET
    propensities_each_type::PT
    idx_func_propensities_each_type::FPT
    type_to_idx::TI
    # maps an agent type to its applicable events
    event_queue::Q
    autogenerate_on_add::Bool
    autogenerate_after_action::Bool
    maxid::Base.RefValue{Int64}
    time::Base.RefValue{Float64}
end

"""
    EventQueueABM <: AgentBasedModel

A concrete implementation of an [`AgentBasedModel`](@ref) which operates in
continuous time, in contrast with the discrete time nature of [`StandardABM`](@ref).

This is still experimental which means that it is subject to breaking changes in the
future. Also, while all the core functionalities have been implemented, this model type 
has some more limited features than `StandardABM`: in particular, visualizations and 
IO functionalities are incomplete.

Here is a summary of how the time evolution of this model works:

A list of possible events that can be created is provided to the model.
The events have four pieces of information:

1. The action that they perform once triggered. The action is a generic Julia function
   `action!(agent, model)` that will act on the agent corresponding to the event.
   Similarly with `agent_step!` for [`StandardABM`](@ref), this function may do anything
   and utilize any function from the Agents.jl [API](@ref) or the entire Julia ecosystem.
   The `action!` function may spawn new events by using the automatic or the manual
   of the [`add_event!`](@ref) function, the default behavior is to generate new events 
   automatically.
2. The propensity of the event. A propensity is a concept similar to a probability mass.
   When automatically generating a new event for an agent,
   first all applicable events for that agent
   are collected. Then, their propensities are calculated. The event generated then
   is selected randomly by weighting each possible event by its propensity.
3. The agent type(s) the event applies to. By default it applies to all types.
4. The timing of the event, i.e., when should it be triggered once it is generated.
   By default this is an exponentially distributed random variable divided by the
   propensity of the event. I.e., it follows a Poisson process with the propensity
   as the "rate". The timings of the events therefore establish the natural
   timescales of the system.

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
`events` is a container (typically a tuple) of instances of [`AgentEvent`](@ref),
which are the events that are scheduled and then affect agents.
The key type of `events` is also what is given to [`add_event!`](@ref),
hence, `events` can be e.g., a dictionary with string keys so that it is
easier to reference events in [`add_event!`](@ref).

By default, each time a new agent is added to the model via [`add_agent!`](@ref), a new
event is generated based on the pool of possible events that can affect the agent.
In this way the simulation can immediatelly start once agents have been added to the model.
You can disable this behavior with a keyword. In this case, you need to manually use
the function [`add_event!`](@ref) to add events to the queue so that the model
can be evolved in time.
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
        warn_deprecation = false, 
        autogenerate_on_add = true,
        autogenerate_after_action = true,
    ) where {A<:AbstractAgent,S<:SpaceType,E,P,R<:AbstractRNG}
    @warn "This model type is still experimental which means that it is subject to breaking changes in the
        future. Also, while all the core functionalities have been implemented, this model type 
        has some more limited features than `StandardABM`: in particular, visualizations and 
        IO functionalities are incomplete."
    end
    agent_validator(A, space, warn)
    C = construct_agent_container(container, A)
    agents = C()
    I = events isa Tuple ? Int : keytype(events)
    queue = PriorityQueue{Tuple{I, Int}, Float64}()
    agent_types = union_types(A)
    type_to_idx = Dict(t => i for (i, t) in enumerate(agent_types))
    idx_events_each_type = [[i for (i, e) in enumerate(events) if t <: e.types] 
                            for t in agent_types]
    propensities_each_type = [zeros(length(e)) for e in idx_events_each_type]
    idx_func_propensities_each_type = [Int[] for _ in idx_events_each_type]
    for i in 1:length(agent_types)
        propensities_type = propensities_each_type[i]
        for (q, j) in enumerate(idx_events_each_type[i])
            if events[j].propensity isa Real
                propensities_type[q] = events[j].propensity
            else
                push!(idx_func_propensities_each_type[i], q)
            end
        end
    end
    ET,PT,FPT,TI,Q = typeof.((idx_events_each_type, propensities_each_type, 
                              idx_func_propensities_each_type, type_to_idx, queue))
    return EventQueueABM{S,A,C,P,E,R,ET,PT,FPT,TI,Q}(
        agents, space, properties, rng, events, idx_events_each_type, 
        propensities_each_type, idx_func_propensities_each_type, type_to_idx, 
        queue, autogenerate_on_add, autogenerate_after_action, Ref(0), Ref(0.0)
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
    if getfield(model, :autogenerate_on_add)
        add_event!(agent, model)
    end
end

"""
    add_event!(agent, model)

Generate a randomly chosen event for the `agent` and add it to the queue,
based on the propensities and as described in [`EventQueueABM`](@ref).

    add_event!(agent, event_idx::Int, t::Real, model::EventQueueABM)

Add a new event to the queue to be triggered for `agent`, based on the index of the
event (from the list of events). The event will trigger in `t` time _from_ the
current time of the `model`.
"""
function add_event!(agent, model)
    events = abmevents(model)
    # Here, we retrieve the applicable events for the agent
    idx = getfield(model, :type_to_idx)[typeof(agent)]
    events_type = getfield(model, :idx_events_each_type)[idx]
    propensities_type = getfield(model, :propensities_each_type)[idx]
    idx_func_propensities_type = getfield(model, :idx_func_propensities_each_type)[idx]
    # After, we update the propensity vector
    for i in idx_func_propensities_type
        event = events[events_type[i]]
        p = event.propensity(agent, model)
        propensities_type[i] = p
    end
    # Then, select an event based on propensities
    event_idx = events_type[sample_propensity(abmrng(model), propensities_type)]
    # The time to the event is generated from the selected event
    selected_event = abmevents(model)[event_idx]
    selected_prop = propensities_type[event_idx]
    t = selected_event.timing(agent, model, selected_prop)
    add_event!(agent, event_idx, t, model)
end
function add_event!(agent::AbstractAgent, event_idx::Int, t::Real, model::EventQueueABM)
    enqueue!(abmqueue(model), (agent.id, event_idx) => t + abmtime(model))
    return
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
    return i
end

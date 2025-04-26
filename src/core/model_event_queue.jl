export EventQueueABM, AgentEvent
export abmqueue, abmevents, abmtime, add_event!
using DataStructures: PriorityQueue

"""
    AgentEvent(; action!, propensity, kinds, timing)

An event instance that can be given to [`EventQueueABM`](@ref).

- `action! = dummystep`: is the function `action!(agent, model)` that will
  act on the agent the event corresponds to. This keyword is mandatory.
  The `action!` function may call [`add_event!`](@ref) to generate new events, regardless
  of the automatic generation of events by Agents.jl.
- `propensity = 1.0`: it can be either a constant real number,
  or a function `propensity(agent, model)` that returns the propensity of the event.
  This function is called when a new event is generated for the given `agent`.
- `types = AbstractAgent`: the types of agents the `action!` function can be applied to.
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

struct EventQueueABM{
    S<:SpaceType,
    A<:AbstractAgent,
    C<:ContainerType{A},
    P,E,R<:AbstractRNG,TF,ET,PT,FPT,Q} <: AgentBasedModel{S}
    # core ABM stuff
    agents::C
    space::S
    properties::P
    rng::R
    maxid::Base.RefValue{Int64}
    time::Base.RefValue{Float64}
    # Specific to event queue
    events::E
    type_func::TF
    idx_events_each_type::ET
    propensities_each_type::PT
    idx_func_propensities_each_type::FPT
    event_queue::Q
    autogenerate_on_add::Bool
    autogenerate_after_action::Bool
end

"""
    EventQueueABM <: AgentBasedModel

A concrete implementation of an [`AgentBasedModel`](@ref) which operates in
continuous time, in contrast with the discrete time nature of [`StandardABM`](@ref).

Here is a summary of how the time evolution of this model works:

A list of possible events that can be created is provided to the model.
The events have four pieces of information:

1. The action that they perform once triggered. The action is a generic Julia function
   `action!(agent, model)` that will act on the agent corresponding to the event.
   Similarly with `agent_step!` for [`StandardABM`](@ref), this function may do anything
   and utilize any function from the Agents.jl [API](@ref) or the entire Julia ecosystem.
   The `action!` function may spawn new events by using [`add_event!`](@ref) function, 
   however the default behavior is to generate new events automatically, see below.
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
   timescales of the ABM.

Events are scheduled in a temporally ordered queue, and once
the model evolution time reaches the event time, the event is "triggered".
This means that first the event action is performed on its corresponding agent.
By default, once an event has finished its action,
a new event is generated for the same agent (if the agent still exists), chosen randomly
based on the propensities as discussed above. Then a time for the new event
is generated and the new event is added back to the queue.
In this way, an event always generates a new event after it has finished its action
(by default; this can be overwritten).
Keep in mind that the scheduling and triggering of events is agnostic to
what the events actually do; even if an event does nothing, it would 
still "use up" the agent's time if scheduled. You can avoid this by assigning
propensity 0 to such events in the propensity function,
according to the agent and model state.

`EventQueueABM` is a generalization of "Gillespie"-like simulations, offering
more power and flexibility than a standard Gillespie simulation,
while also allowing "Gillespie"-like configuration with the default settings.

Here is how to construct an `EventQueueABM`:

    EventQueueABM(AgentType, events [, space]; kwargs...)

Create an instance of an [`EventQueueABM`](@ref).

The model expects agents of type `AgentType(s)` living in the given `space`.
`AgentType(s)` is the result of [`@agent`](@ref) or `@multiagent` or
a `Union` of agent types.

`space` is a subtype of `AbstractSpace`, see [Space](@ref available_spaces) for all available spaces.

`events` is a container of instances of [`AgentEvent`](@ref),
which are the events that are scheduled and then affect agents.
A `Tuple` or `NamedTuple` for `events` leads to optimal performance.
The key type of `events` is also what is given as index to [`add_event!`](@ref).

By default, each time a new agent is added to the model via [`add_agent!`](@ref), a new
event is generated based on the pool of possible events that can affect the agent.
In this way the simulation can immediatelly start once agents have been added to the model.
You can disable this behavior with a keyword. In this case, you need to manually use
the function [`add_event!`](@ref) to add events to the queue so that the model
can be evolved in time.
(you can always use this function regardless of the default event scheduling behavior)

## Keyword arguments

- `container, properties, rng, warn`: same as in [`StandardABM`](@ref).
- `autogenerate_on_add::Bool = true`: whether to automatically generate a new event for
  an agent when the agent is added to the model.
- `autogenerate_after_action::Bool = true`: whether to automatically generate a new
  event for an agent after an event affected said agent has been triggered.


!!! warn "No IO yet"
    This model does not yet support IO operations such as [`save_checkpoint`](@ref AgentsIO.save_checkpoint).
    Pull Requests that implement this are welcomed!
"""
function EventQueueABM(
        A::Type, events,
        space::S = nothing;
        container::Type = Dict,
        properties::P = nothing,
        rng::R = Random.default_rng(),
        warn = true,
        autogenerate_on_add = true,
        autogenerate_after_action = true,
    ) where {S<:SpaceType,P,R<:AbstractRNG}
    if container == StructVector
        if !(A <: SoAType)
            @warn "The agent type passed to the model constructor is of type $A but a model with a 
            StructVector container will have agents of type SoAType{$A}. Pass this to the constructor to 
            remove this warning." maxlog=1
        else
            A = A.body.parameters[1]
        end
    end
    agents = construct_agent_container(container, A)
    events = SizedVector{length(events), Union{typeof.(events)...}}(events...)

    # the queue stores pairs of (agent ID, event index) mapping them to their trigger time
    queue = BinaryHeap(
                Base.By(last, DataStructures.FasterForward()), 
                Pair{Tuple{Int, Int}, Float64}[]
            )

    agent_types = is_sumtype(A) ? values(allvariants(A)) : union_types(A)

    if is_sumtype(A) 
        type_func = LightSumTypes.variant_idx 
    else 
        type_to_idx = Dict(t => i for (i, t) in enumerate(agent_types))
        type_func = (agent) -> type_to_idx[typeof(agent)]
    end

    # precompute a vector mapping the agent type index to a
    # vectors of indices, each vector corresponding
    # to all valid events that can apply to a given agent type
    idx_events_each_type = [[i for (i, e) in enumerate(events) if t <: e.types] 
                            for t in agent_types]
    # initialize vectors for the propensities (they are updated in-place later)
    propensities_each_type = [zeros(length(e)) for e in idx_events_each_type]

    # We loop over all propensities. For those that are functions, we can
    # update the corresponding propensities entry, which will stay fixed.
    # For the others, we keep track of the indices of the events whose
    # propensities is a function. Later on when we compute propensities,
    # only the indices with propensity <: Function are re-updated!
    idx_func_propensities_each_type = [Int[] for _ in idx_events_each_type]
    for i in eachindex(agent_types)
        propensities_type = propensities_each_type[i]
        for (q, j) in enumerate(idx_events_each_type[i])
            if events[j].propensity isa Real
                propensities_type[q] = events[j].propensity
            else # propensity is a custom function!
                push!(idx_func_propensities_each_type[i], q)
            end
        end
    end
    # the above three containers have been created to accelerate
    # the creation and enqueing of new events. They are all vectors
    # because we use the index of `type_to_idx` to access them.

    # construct the type
    E,TF,ET,PT,FPT,Q = typeof.((
        events, type_func, idx_events_each_type, propensities_each_type,
        idx_func_propensities_each_type, queue
    ))
    return EventQueueABM{S,A,typeof(agents),P,E,R,TF,ET,PT,FPT,Q}(

        agents, space, properties, rng, Ref(0), Ref(0.0),

        events, type_func, idx_events_each_type,
        propensities_each_type, idx_func_propensities_each_type,
        queue, autogenerate_on_add, autogenerate_after_action,
    )
end

function Base.getindex(model::EventQueueABM{S, A, C}, id::Int) where {S,A,C<:StructVector}
    return AgentWrapperSoA{A}(agent_container(model), id)
end
###########################################################################################
# %% Adding events to the queue
###########################################################################################
# This function ensures that once an agent is added into the model,
# an event is created and added for it. It is called internally
# by `add_agent_to_container!`.
function extra_actions_after_add!(agent, model::EventQueueABM)
    if getfield(model, :autogenerate_on_add)
        add_event!(agent, model)
    end
end

"""
    add_event!(agent, model)

Generate a randomly chosen event for the `agent` and add it to the queue,
based on the propensities and as described in [`EventQueueABM`](@ref).

    add_event!(agent, event_idx, t::Real, model::EventQueueABM)

Add a new event to the queue to be triggered for `agent`, based on the index of the
event (from the given `events` to the `model`). The event will trigger in `t` time _from_ the
current time of the `model`.
"""
function add_event!(agent, model) # TODO: Study type stability of this function
    events = abmevents(model)
    # Here, we retrieve the applicable events for the agent and corresponding info
    idx = getfield(model, :type_func)(agent)
    events_type = getfield(model, :idx_events_each_type)[idx]
    propensities_type = getfield(model, :propensities_each_type)[idx]
    idx_func_propensities_type = getfield(model, :idx_func_propensities_each_type)[idx]
    # After, we update the propensity vector
    # (only the propensities that are custom functions need updating)
    for i in idx_func_propensities_type
        event = events[events_type[i]]
        p = event.propensity(agent, model)
        propensities_type[i] = p
    end
    # Then, select an event based on propensities
    # The time to the event is generated from the selected event
    prop_idx = sample_propensity(abmrng(model), propensities_type)
    event_idx = events_type[prop_idx] 
    selected_event = events[event_idx]
    selected_prop = propensities_type[prop_idx]
    t = selected_event.timing(agent, model, selected_prop)
    # we then propagate to the direct function
    add_event!(agent, event_idx, t, model)
end

function add_event!(agent::AbstractAgent, event_idx, t::Real, model::EventQueueABM)
    push!(abmqueue(model), (agent.id, event_idx) => t + abmtime(model))
    return
end

# from StatsBase.jl
function sample_propensity(rng, wv::AbstractVector)
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

###########################################################################################
# %% `AgentBasedModel` API: standard accessors
###########################################################################################
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

discretimeabm(::EventQueueABM) = false

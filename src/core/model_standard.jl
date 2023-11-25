export StandardABM, UnremovableABM
export abmscheduler
export dummystep

ContainerType{A} = Union{AbstractDict{Int,A}, AbstractVector{A}}

# And the two implementations here are just variants with different `C` type.
struct StandardABM{
    S<:SpaceType,
    A<:AbstractAgent,
    C<:ContainerType{A},
    T,G,K,F,P,R<:AbstractRNG} <: AgentBasedModel{S}
    agents::C
    agent_step::G
    model_step::K
    space::S
    scheduler::F
    properties::P
    rng::R
    maxid::Base.RefValue{Int64}
    agents_types::T
    agents_first::Bool
end

# Extend mandatory internal API for `AgentBasedModel`

containertype(::StandardABM{S,A,C}) where {S,A,C} = C
agenttype(::StandardABM{S,A}) where {S,A} = A

"""
    union_types(U::Type)

Return a tuple of types within a `Union`.
"""
union_types(T::Type) = (T,)
union_types(T::Union) = (union_types(T.a)..., union_types(T.b)...)

"""
    StandardABM <: AgentBasedModel

The most standard concrete implementation of an [`AgentBasedModel`](@ref),
as well as the default version of the generic [`AgentBasedModel`](@ref) constructor.

    StandardABM(AgentType [, space]; properties, kwargs...) → model

Creates a model expecting agents of type `AgentType` living in the given `space`.
It can support supports multiple agent types by passing a `Union` of agent types
as `AgentType`. Have a look at [Performance Tips](@ref) for potential
drawbacks of this approach.

`space` is a subtype of `AbstractSpace`, see [Space](@ref Space) for all available spaces.
If it is omitted then all agents are virtually in one position and there is no spatial structure.
Spaces are mutable objects and are not designed to be shared between models.
Create a fresh instance of a space with the same properties if you need to do this.

The evolution rules are functions given to the keywords `agent_step!`, `model_step!`, `schedule`. If
`agent_step!` is not provided, the evolution rules is just the function given to `model_step!`.
Each step of a simulation with `StandardABM` proceeds as follows:
If `agent_step!` is not provided, then a simulation step is equivalent with
calling `model_step!`. If `agent_step!` is provided, then a simulation step
first schedules agents by calling the scheduler. Then, it applies the `agent_step!` function
to all scheduled agents. Then, the `model_step!` function is called
(optionally, the `model_step!` function may be called before activating the agents).

`StandardABM` stores by default agents in a dictionary mapping unique `Int` IDs to agents.
For better performance, in case the number of agents can only increase during the model
evolution, a vector can be used instead, see keyword `container`.

## Keywords

- `agent_step! = dummystep`: the optional stepping function for each agent contained in the
  model. For complicated models, it could be more suitable to use only `model_step!` to evolve
  the model.
- `model_step! = dummystep`: the optional stepping function for the model.
- `container = Dict`: the type of container the agents are stored at. Use `Vector` if no agents are removed
  during the simulation. This allows storing agents more efficiently, yielding faster retrieval and
  iteration over agents.
- `properties = nothing`: additional model-level properties that the user may decide upon
  and include in the model. `properties` can be an arbitrary container of data,
  however it is most typically a `Dict` with `Symbol` keys, or a composite type (`struct`).
- `scheduler = Schedulers.fastest`: is the scheduler that decides the (default)
  activation order of the agents. See the [scheduler API](@ref Schedulers) for more options.
- `rng = Random.default_rng()`: the random number generation stored and used by the model
  in all calls to random functions. Accepts any subtype of `AbstractRNG`.
- `agents_first::Bool = true`: whether to schedule and activate agents first and then
  call the `model_step!` function, or vice versa.
- `warn=true`: some type tests for `AgentType` are done, and by default
  warnings are thrown when appropriate.
"""
function StandardABM(
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
    warn_deprecation = true
) where {A<:AbstractAgent,S<:SpaceType,G,K,F,P,R<:AbstractRNG}
    if warn_deprecation && agent_step! == dummystep && model_step! == dummystep
        @warn "From version 6.0 it is necessary to pass at least one of agent_step! or model_step!
         as keywords argument when defining the model. The old version is deprecated. Passing these
         functions to methods of the library which required them before version 6.0 is also deprecated
         since they can be retrieved from the model instance, in particular this means it is not needed to
         pass the stepping functions in step!, run!, offline_run!, ensemblerun!, abmplot, abmplot!, abmexploration
         abmvideo and ABMObservable"
    end
    agent_validator(A, space, warn)
    C = construct_agent_container(container, A)
    agents = C()
    agents_types = union_types(A)
    T = typeof(agents_types)
    return StandardABM{S,A,C,T,G,K,F,P,R}(agents, agent_step!, model_step!, space, scheduler,
                                          properties, rng, Ref(0), agents_types, agents_first)
end

function StandardABM(agent::AbstractAgent, args::Vararg{Any, N}; kwargs...) where {N}
    return StandardABM(typeof(agent), args...; kwargs...)
end

construct_agent_container(::Type{<:Dict}, A) = Dict{Int,A}
construct_agent_container(::Type{<:Vector}, A) = Vector{A}
construct_agent_container(container, A) = throw(
    "Unrecognised container $container, please specify either Dict or Vector."
)


"""
    dummystep(model)

Used instead of `model_step!` in [`StandardABM`](@ref) if no function is useful to be defined.

    dummystep(agent, model)

Used instead of `agent_step!` in [`StandardABM`](@ref) if no function is useful to be defined.
"""
dummystep(model) = nothing
dummystep(agent, model) = nothing

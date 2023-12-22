export StandardABM, UnremovableABM
export abmscheduler
using StaticArrays: SizedVector

ContainerType{A} = Union{AbstractDict{Int,A}, AbstractVector{A}}

# And the two implementations here are just variants with different `C` type.
struct StandardABM{
    S<:SpaceType,
    A<:AbstractAgent,
    C<:ContainerType{A},
    G,K,F,P,R<:AbstractRNG} <: AgentBasedModel{S}
    agents::C
    agent_step::G
    model_step::K
    space::S
    scheduler::F
    properties::P
    rng::R
    maxid::Base.RefValue{Int64}
    time::Base.RefValue{Int64}
    agents_first::Bool
end

const DictStandardABM = StandardABM{S,A,Dict{Int,A}} where {S,A} 
const VecStandardABM = StandardABM{S,A,Vector{A}} where {S,A}

# Extend mandatory internal API for `AgentBasedModel`

containertype(::StandardABM{S,A,C}) where {S,A,C} = C

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
    return StandardABM{S,A,C,G,K,F,P,R}(agents, agent_step!, model_step!, space, scheduler,
                                        properties, rng, Ref(0), Ref(0), agents_first)
end

function StandardABM(agent::AbstractAgent, args::Vararg{Any, N}; kwargs...) where {N}
    return StandardABM(typeof(agent), args...; kwargs...)
end

construct_agent_container(::Type{<:Dict}, A) = Dict{Int,A}
construct_agent_container(::Type{<:Vector}, A) = Vector{A}
construct_agent_container(container, A) = throw(
    "Unrecognised container $container, please specify either Dict or Vector."
)

agenttype(::StandardABM{S,A}) where {S,A} = A

#######################################################################################
# %% Model accessing api
#######################################################################################

nextid(model::DictStandardABM) = getfield(model, :maxid)[] + 1
nextid(model::VecStandardABM) = nagents(model) + 1

function add_agent_to_model!(agent::AbstractAgent, model::DictStandardABM)
    if haskey(agent_container(model), agent.id)
        error("Can't add agent to model. There is already an agent with id=$(agent.id)")
    else
        agent_container(model)[agent.id] = agent
    end
    # Only the `StandardABM` implementation actually uses the `maxid` field.
    maxid = getfield(model, :maxid)
    new_id = agent.id
    if maxid[] < new_id; maxid[] = new_id; end
    return
end

function add_agent_to_model!(agent::AbstractAgent, model::VecStandardABM)
    agent.id != nagents(model) + 1 && error("Cannot add agent of ID $(agent.id) in a vector ABM of $(nagents(model)) agents. Expected ID == $(nagents(model)+1).")
    push!(agent_container(model), agent)
    return
end

function remove_agent_from_model!(agent::AbstractAgent, model::DictStandardABM)
    delete!(agent_container(model), agent.id)
    return
end

function remove_agent_from_model!(agent::AbstractAgent, model::VecStandardABM)
    error("Cannot remove agents in `UnremovableABM`.")
end

random_id(model::StandardABM) = rand(abmrng(model), agent_container(model)).first
random_agent(model::StandardABM) = rand(abmrng(model), agent_container(model)).second

#######################################################################################
# %% Model construction validation
#######################################################################################
"""
    agent_validator(AgentType, space)
Validate the user supplied agent (subtype of `AbstractAgent`).
Checks for mutability and existence and correct types for fields depending on `SpaceType`.
"""
function agent_validator(
    ::Type{A},
    space::S,
    warn::Bool,
) where {A<:AbstractAgent,S<:SpaceType}
    # Check A for required properties & fields
    if isconcretetype(A)
        do_checks(A, space, warn)
    else
        warn && @warn """
        Agent type is not concrete. If your agent is parametrically typed, you're probably
        seeing this warning because you gave `Agent` instead of `Agent{Float64}`
        (for example) to this function. You can also create an instance of your agent
        and pass it to this function. If you want to use `Union` types for mixed agent
        models, you can silence this warning.
        If you are using `ContinuousAgent{D}` as agent type in version 6+, update
        to the new two-parameter version `ContinuousAgent{D,Float64}` to obtain
        the same behavior as previous Agents.jl versions.
        """
        for type in union_types(A)
            do_checks(type, space, warn)
        end
    end
end

# Note: This function needs to be updated every time a new space is defined!
"""
    do_checks(agent, space)
Helper function for `agent_validator`.
"""
function do_checks(::Type{A}, space::S, warn::Bool) where {A<:AbstractAgent, S<:SpaceType}
    if warn
        isbitstype(A) &&
        @warn "Agent type is not mutable, and most library functions assume that it is."
    end
    (any(isequal(:id), fieldnames(A)) && fieldnames(A)[1] == :id) ||
    throw(ArgumentError("First field of agent type must be `id` (and should be of type `Int`)."))
    fieldtype(A, :id) <: Integer ||
    throw(ArgumentError("`id` field in agent type must be of type `Int`."))
    if space !== nothing
        (any(isequal(:pos), fieldnames(A)) && fieldnames(A)[2] == :pos) ||
        throw(ArgumentError("Second field of agent type must be `pos` when using a space."))
        # Check `pos` field in A has the correct type
        pos_type = fieldtype(A, :pos)
        space_type = typeof(space)
        if space_type <: GraphSpace && !(pos_type <: Integer)
            throw(ArgumentError("`pos` field in agent type must be of type `Int` when using GraphSpace."))
        elseif space_type <: GridSpace && !(pos_type <: NTuple{D,Integer} where {D})
            throw(ArgumentError("`pos` field in agent type must be of type `NTuple{Int}` when using GridSpace."))
        elseif space_type <: ContinuousSpace
            if pos_type <: NTuple{D,<:AbstractFloat} where {D}
                warn && @warn "Using `NTuple` for the `pos` and `vel` fields of agent types in ContinuousSpace is deprecated. Use `SVector` instead."
            elseif !(pos_type <: SVector{D,<:AbstractFloat} where {D} || (!isconcretetype(A) && pos_type <: SVector{D} where {D}))
                throw(ArgumentError("`pos` field in agent type must be of type `SVector{<:AbstractFloat}` when using ContinuousSpace."))
            end
            if any(isequal(:vel), fieldnames(A)) &&
               !(
                    fieldtype(A, :vel) <: NTuple{D,<:AbstractFloat} where {D} ||
                    fieldtype(A, :vel) <: SVector{D,<:AbstractFloat} where {D} ||
                    (!isconcretetype(A) && fieldtype(A, :vel) <: SVector{D} where {D})
                )
                throw(ArgumentError("`vel` field in agent type must be of type `SVector{<:AbstractFloat}` when using ContinuousSpace."))
            end
            if eltype(space) != eltype(pos_type)
                # extra condition for backward compatibility (#855)
                # we don't want to throw an error if ContinuousAgent{D} is used with a Float64 space
                if isnothing(match(r"ContinuousAgent{\d}", string(A))) || eltype(space) != Float64
                    throw(ArgumentError("`pos` field in agent type must be of the same type of the `extent` field in ContinuousSpace."))
                end
            end
        end
    end
end

#######################################################################################
# %% Pretty printing
#######################################################################################
function Base.show(io::IO, abm::StandardABM{S,A,C}) where {S,A,C}
    n = isconcretetype(A) ? nameof(A) : string(A)
    typecontainer = C isa Dict ? Dict : Vector
    s = "StandardABM with $(nagents(abm)) agents of type $(n)"
    s *= "\n agents container: $(typecontainer)"
    if abmspace(abm) === nothing
        s *= "\n space: nothing (no spatial structure)"
    else
        s *= "\n space: $(sprint(show, abmspace(abm)))"
    end
    s *= "\n scheduler: $(schedulername(abmscheduler(abm)))"
    print(io, s)
    if abmproperties(abm) ≠ nothing
        if typeof(abmproperties(abm)) <: Dict
            props = collect(keys(abmproperties(abm)))
        else
            props = collect(propertynames(abmproperties(abm)))
        end
        print(io, "\n properties: ", join(props, ", "))
    end
end

schedulername(x::Union{Function,DataType}) = nameof(x)
schedulername(x) = Symbol(typeof(x))

function remove_all_from_model!(model::StandardABM)
    empty!(agent_container(model))
end

export ABM, StandardABM, UnremovableABM
using StaticArrays: SizedVector

ContainerType{A} = Union{AbstractDict{Int,A}, AbstractVector{A}}

# And the three implementations here are just variants with different `C` type.
struct SingleContainerABM{S<:SpaceType,A<:AbstractAgent,C<:ContainerType{A},F,P,R<:AbstractRNG} <: AgentBasedModel{S,A}
    agents::C
    space::S
    scheduler::F
    properties::P
    rng::R
    maxid::Base.RefValue{Int64}
end

const SCABM = SingleContainerABM
const StandardABM = SingleContainerABM{S,A,Dict{Int,A}} where {S,A,C}
const UnremovableABM = SingleContainerABM{S,A,Vector{A}} where {S,A,C}

containertype(::SingleContainerABM{S,A,C}) where {S,A,C} = C

"""
    union_types(U::Type)
Return a tuple of types within a `Union`.
"""
union_types(T::Type) = (T,)
union_types(T::Union) = (union_types(T.a)..., union_types(T.b)...)

"""
    SingleContainerABM(AgentType [, space]; properties, kwargs...) → model

A concrete version of [`AgentBasedModel`](@ref) that stores all agents in a
single container. Offers the variants:

- [`StandardABM`](@ref)
- [`UnremovableABM`](@ref)
"""
function SingleContainerABM(
    ::Type{A},
    space::S = nothing;
    container::Type = Dict{Int},
    scheduler::F = Schedulers.fastest,
    properties::P = nothing,
    rng::R = Random.default_rng(),
    warn = true
) where {A<:AbstractAgent,S<:SpaceType,F,P,R<:AbstractRNG}
    agent_validator(A, space, warn)
    C = construct_agent_container(container, A)
    agents = C()
    return SingleContainerABM{S,A,C,F,P,R}(agents, space, scheduler, properties, rng, Ref(0))
end

function SingleContainerABM(agent::AbstractAgent, args::Vararg{Any, N}; kwargs...) where {N}
    return SingleContainerABM(typeof(agent), args...; kwargs...)
end

construct_agent_container(::Type{<:Dict}, A) = Dict{Int,A}
construct_agent_container(::Type{<:Vector}, A) = Vector{A}
construct_agent_container(container, A) = throw(
    "Unrecognised container $container, please specify either Dict or Vector."
)

"""
    StandardABM(AgentType [, space]; properties, kwargs...) → model

The most standard concrete implementation of an [`AgentBasedModel`](@ref),
as well as the default version of the generic [`AgentBasedModel`](@ref) constructor.
`StandardABM` stores agents in a dictionary mapping unique `Int` IDs to agents.
See also [`UnremovableABM`](@ref).
"""
StandardABM(args::Vararg{Any, N}; kwargs...) where {N} = SingleContainerABM(args...; kwargs..., container=Dict{Int})

"""
    UnremovableABM(AgentType [, space]; properties, kwargs...) → model

Similar to [`StandardABM`](@ref), but agents cannot be removed, only added.
This allows storing agents more efficiently in a standard Julia `Vector` (as opposed to
the `Dict` used by [`StandardABM`](@ref), yielding faster retrieval and iteration over agents.

It is mandatory that the agent ID is exactly the same as the agent insertion
order (i.e., the 5th agent added to the model must have ID 5). If not,
an error will be thrown by [`add_agent!`](@ref).
"""
UnremovableABM(args::Vararg{Any, N}; kwargs...) where {N} = SingleContainerABM(args...; kwargs..., container=Vector)


#######################################################################################
# %% Model accessing api
#######################################################################################
nextid(model::StandardABM) = getfield(model, :maxid)[] + 1
nextid(model::UnremovableABM) = nagents(model) + 1

function add_agent_to_model!(agent::A, model::StandardABM) where {A<:AbstractAgent}
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

function add_agent_to_model!(agent::A, model::UnremovableABM) where {A<:AbstractAgent}
    agent.id != nagents(model) + 1 && error("Cannot add agent of ID $(agent.id) in a vector ABM of $(nagents(model)) agents. Expected ID == $(nagents(model)+1).")
    push!(agent_container(model), agent)
    return
end

function remove_agent_from_model!(agent::A, model::StandardABM) where {A<:AbstractAgent}
    delete!(agent_container(model), agent.id)
    return
end

function remove_agent_from_model!(agent::A, model::UnremovableABM) where {A<:AbstractAgent}
    error("Cannot remove agents in a `UnremovableABM`")
end

random_agent(model::StandardABM) = rand(abmrng(model), agent_container(model)).first
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
modelname(abm::ABM) = modelname(agent_container(abm))
modelname(::Dict) = "StandardABM"
modelname(::Vector) = "UnremovableABM"

function Base.show(io::IO, abm::SingleContainerABM{S,A}) where {S,A}
    n = isconcretetype(A) ? nameof(A) : string(A)
    s = "$(modelname(abm)) with $(nagents(abm)) agents of type $(n)"
    if abm.space === nothing
        s *= "\n space: nothing (no spatial structure)"
    else
        s *= "\n space: $(sprint(show, abmspace(abm)))"
    end
    s *= "\n scheduler: $(schedulername(abmscheduler(abm)))"
    print(io, s)
    if abm.properties ≠ nothing
        if typeof(abm.properties) <: Dict
            props = collect(keys(abm.properties))
        else
            props = collect(propertynames(abm.properties))
        end
        print(io, "\n properties: ", join(props, ", "))
    end
end

schedulername(x::Union{Function,DataType}) = nameof(x)
schedulername(x) = Symbol(typeof(x))


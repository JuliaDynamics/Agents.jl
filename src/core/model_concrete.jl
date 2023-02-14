export ABM, SingleContainerABM, UnkillableABM, FixedMassABM
using StaticArraysCore: SizedVector

ContainerType{A} = Union{AbstractDict{Int,A}, AbstractVector{A}}

# TODO: This will become `SingleContainerABM`.
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
const StandardABM{A,S} = SingleContainerABM{A,S,Dict{Int,A}}
const UnkillableABM{A,S} = SingleContainerABM{A,S,Vector{A}}
const FixedMassABM{A,S} = SingleContainerABM{A,S,SizedVector{A}}

containertype(::SingleContainerABM{S,A,C}) where {S,A,C} = C

function construct_agent_container(container, A)
    if container <: Dict
        return Dict{Int,A}
    elseif container <: Vector
        return Vector{A}
    else
        throw(ArgumentError("Unrecognised container $container, please specify either Dict or Vector."))
    end
end

"""
    union_types(U::Type)
Return a tuple of types within a `Union`.
"""
union_types(T::Type) = (T,)
union_types(T::Union) = (union_types(T.a)..., union_types(T.b)...)

"""
    SingleContainerABM(AgentType [, space]; properties, kwargs...) → model

Create an agent-based model from the given agent type and `space`.
You can provide an agent _instance_ instead of type, and the type will be deduced.

The agents are stored in a dictionary that maps unique IDs (integers)
to agents. Use `model[id]` to get the agent with the given `id`.
See also [`UnkillableABM`](@ref) and [`FixedMassABM`](@ref) for different storage types
that yield better performance in case number of agents can only increase, or stays constant,
during the model evolution.

`space` is a subtype of `AbstractSpace`, see [Space](@ref Space) for all available spaces.
If it is omitted then all agents are virtually in one position and there is no spatial structure.

**Note:** Spaces are mutable objects and are not designed to be shared between models.
Create a fresh instance of a space with the same properties if you need to do this.

**Note:** Agents.jl supports multiple agent types by passing a `Union` of agent types
as `AgentType`. However, please have a look at [Performance Tips](@ref) for potential
drawbacks of this approach.

**Note:** You should only store agents in a vector if you will never remove agents from the model
once they are added.

## Keywords
`properties = nothing` is additional model-level properties (typically a dictionary)
that can be accessed as `model.properties`. If `properties` is a dictionary with
key type `Symbol`, or if it is a struct, then the syntax
`model.name` is shorthand for `model.properties[:name]` (or `model.properties.name`
for structs).
This syntax can't be used for `name` being `agents, space, scheduler, properties, rng, maxid`,
which are the fields of `SingleContainerABM`.

`scheduler = Schedulers.fastest` decides the order with which agents are activated
(see e.g. [`Schedulers.by_id`](@ref) and the scheduler API).
`scheduler` is only meaningful if an agent-stepping function is defined for [`step!`](@ref)
or [`run!`](@ref), otherwise a user decides a scheduler in the model-stepping function,
as illustrated in the [Advanced stepping](@ref) part of the tutorial.

`rng = Random.default_rng()` provides random number generation to the model.
Accepts any subtype of `AbstractRNG` and is accessed by `model.rng`.

`warn=true`: Type tests for `AgentType` are done, and by default
warnings are thrown when appropriate.
"""
function SingleContainerABM(
    ::Type{A},
    space::S = nothing;
    container::Type = Dict{Int,A},
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

function SingleContainerABM(agent::AbstractAgent, args...; kwargs...)
    return SingleContainerABM(typeof(agent), args...; kwargs...)
end

"""
    UnkillableABM(AgentType [, space]; properties, kwargs...) → model
Similar to [`SingleContainerABM`](@ref), but agents cannot be removed, only added.
This allows storing agents more efficiently in a standard Julia `Vector` (as opposed to
the `Dict` used by [`SingleContainerABM`](@ref), yielding faster retrieval and iteration over agents.

It is mandatory that the agent ID is exactly the same as the agent insertion
order (i.e., the 5th agent added to the model must have ID 5). If not,
an error will be thrown by [`add_agent!`](@ref).
"""
UnkillableABM(args...; kwargs...) = SingleContainerABM(args...; container=Vector)

"""
    FixedMassABM(agent_vector [, space]; properties, kwargs...) → model
Similar to [`SingleContainerABM`](@ref), but agents cannot be removed or added.
Hence, all agents in the model must be provided in advance as a vector.
This allows storing agents into a `SizedVector`, a special vector with statically typed
size which is the same as the size of the input `agent_vector`.
This version of agent based model has slightly better iteration and retrieval speed
than [`UnkillableABM`](@ref).

It is mandatory that the agent ID is exactly the same as its position
in the given `agent_vector`.
"""
function FixedMassABM(
    agents::AbstractVector{A},
    space::S = nothing;
    scheduler::F = Schedulers.fastest,
    properties::P = nothing,
    rng::R = Random.default_rng(),
    warn = true
) where {A<:AbstractAgent, S<:SpaceType,F,P,R<:AbstractRNG}
    C = SizedVector{length(agents), A}
    fixed_agents = C(agents)
    # Validate that agent ID is the same as its order in the vector.
    for (i, a) in enumerate(agents)
        i ≠ a.id && throw(ArgumentError("$(i)-th agent had ID $(a.id) instead of $i."))
    end
    agent_validator(A, space, warn)
    return SingleContainerABM{S,A,C,F,P,R}(fixed_agents, space, scheduler, properties, rng, Ref(0))
end

#######################################################################################
# %% Model accessing api
#######################################################################################
nextid(model::StandardABM) = model.maxid[] + 1
nextid(::FixedMassABM) = error("There is no `nextid` in a `FixedMassABM`. Most likely an internal error.")

function add_agent_to_model!(agent, model::SingleContainerABM{<:SpaceType,A,Dict{Int, A}}) where {A<:AbstractAgent}
    if haskey(agent_container(model), agent.id)
        error("Can't add agent to model. There is already an agent with id=$(agent.id)")
    else
        agent_container(model)[agent.id] = agent
    end
    # Only the `Dict` implementation actually uses the `maxid` field.
    # The `Vector` one uses the defaults, and the `Sized` one errors anyways.
    maxid = getfield(model, :maxid)
    if maxid[] < agent.id; maxid[] = agent.id; end
    return
end

function add_agent_to_model!(agent, model::UnkillableABM)
    agent.id == nagents(model) + 1 || error("Cannot add agent of ID $(agent.id) in a vector ABM of $(nagents(model)) agents. Expected ID == $(nagents(model)+1).")
    push!(agent_container(model), agent)
    return
end

function remove_agent_from_model!(agent::A, model::SingleContainerABM{<:SpaceType,A,<:AbstractDict{Int,A}}) where {A<:AbstractAgent}
    delete!(agent_container(model), agent.id)
end
function remove_agent_from_model!(::A, model::SingleContainerABM{<:SpaceType,A,<:AbstractVector}) where {A<:AbstractAgent}
    error(
    "Cannot remove agents stored in $(containertype(model)). "*
    "Use the vanilla `SingleContainerABM` to be able to remove agents."
    )
end

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
        elseif space_type <: ContinuousSpace || space_type <: ContinuousSpace
            if !(pos_type <: NTuple{D,<:AbstractFloat} where {D})
                throw(ArgumentError("`pos` field in agent type must be of type `NTuple{<:AbstractFloat}` when using ContinuousSpace."))
            end
            if warn &&
               any(isequal(:vel), fieldnames(A)) &&
               !(fieldtype(A, :vel) <: NTuple{D,<:AbstractFloat} where {D})
                @warn "`vel` field in agent type should be of type `NTuple{<:AbstractFloat}` when using ContinuousSpace."
            end
        end
    end
end

#######################################################################################
# %% Pretty printing
#######################################################################################
modelname(abm::ABM) = modelname(agent_container(abm))
modelname(::Dict) = "StandardABM"
modelname(::Vector) = "UnkillableABM"
modelname(::SizedVector) = "FixedMassABM"

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

export ABM, AgentBasedModel, UnkillableABM, FixedMassABM

#######################################################################################
# %% Fundamental type definitions
#######################################################################################

abstract type AbstractSpace end
SpaceType = Union{Nothing,AbstractSpace}

abstract type DiscreteSpace <: AbstractSpace end

# This is a collection of valid position types, sometimes used for ambiguity resolution
ValidPos = Union{
    Int, # graph
    NTuple{N,Int}, # grid
    NTuple{M,<:AbstractFloat}, # continuous
    Tuple{Int,Int,Float64} # osm
} where {N,M}

ContainerType{A} = Union{AbstractDict{Int,A}, AbstractVector{A}}

struct AgentBasedModel{S<:SpaceType,A<:AbstractAgent,C<:ContainerType{A},F,P,R<:AbstractRNG}
    agents::C
    space::S
    scheduler::F
    properties::P
    rng::R
    maxid::Base.RefValue{Int64}
end

"""
`ABM` is an alias for `AgentBasedModel`.
"""
const ABM = AgentBasedModel

const UnkillableABM{A,S} = ABM{A,S,Vector{A}}
const FixedMassABM{A,S} = ABM{A,S,SizedVector{A}} #TODO add utility functions for (creation of) FMABMs?

containertype(::ABM{S,A,C}) where {S,A,C} = C
agenttype(::ABM{S,A}) where {S,A} = A
spacetype(::ABM{S}) where {S} = S

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
    AgentBasedModel(AgentType [, space]; properties, kwargs...) → model
Create an agent-based model from the given agent type and `space`.
You can provide an agent _instance_ instead of type, and the type will be deduced.
`ABM` is equivalent with `AgentBasedModel`.

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
which are the fields of `AgentBasedModel`.

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
function AgentBasedModel(
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
    return ABM{S,A,C,F,P,R}(agents, space, scheduler, properties, rng, Ref(0))
end

function AgentBasedModel(agent::AbstractAgent, args...; kwargs...)
    return ABM(typeof(agent), args...; kwargs...)
end

"""
    UnkillableABM(AgentType [, space]; properties, kwargs...) → model
Similar to [`AgentBasedModel`](@ref), but agents cannot be removed, only added.
This allows storing agents more efficiently in a standard Julia `Vector` (as opposed to
the `Dict` used by [`AgentBasedModel`](@ref), yielding faster retrieval and iteration over agents.

It is mandatory that the agent ID is exactly the same as the agent insertion
order (i.e., the 5th agent added to the model must have ID 5). If not,
an error will be thrown by [`add_agent!`](@ref).
"""
UnkillableABM(args...; kwargs...) = AgentBasedModel(args...; container=Vector)

"""
    FixedMassABM(agent_vector [, space]; properties, kwargs...) → model
Similar to [`AgentBasedModel`](@ref), but agents cannot be removed or added.
Hence, all agents in the model must be provided in advance as a vector.
This allows storing agents into a `SizedVector`, a special vector with statically typed
size which is the same as the size of the input `agent_vector`.
This version of agent based model has slightly better iteration and retrieval speed
than [`UnkillableABM`](@ref).
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
    # println(C)
    # println(C<:AbstractVector)
    fixed_agents = C(agents)
    # println(typeof(fixed_agents))
    agent_validator(A, space, warn)
    return ABM{S,A,C,F,P,R}(fixed_agents, space, scheduler, properties, rng, Ref(0))
end

# TypeError: in AgentBasedModel, in C, expected
# C<:Union{AbstractDict{Int64, Agent0}, AbstractVector{Agent0}}, got
# Type{StaticArraysCore.SizedVector{10, T} where T}

#######################################################################################
# %% Model accessing api
#######################################################################################
export random_agent, nagents, allagents, allids, nextid, seed!

"""
    model[id]
    getindex(model::ABM, id::Integer)

Return an agent given its ID.
"""
Base.getindex(m::ABM, id::Integer) = m.agents[id]

"""
    model[id] = agent
    setindex!(model::ABM, agent::AbstractAgent, id::Int)

Add an `agent` to the `model` at a given index: `id`.
Note this method will return an error if the `id` requested is not equal to `agent.id`.
**Internal method, use [`add_agents!`](@ref) instead to actually add an agent.**
"""
function Base.setindex!(m::ABM, args...; kwargs...)
    error("`setindex!` or `model[id] = agent` are invalid. Use `add_agent!(model, agent)` "*
    "or other variants of an `add_agent_...` function to add agents to an ABM.")
end

"""
    nextid(model::ABM) → id
Return a valid `id` for creating a new agent with it.
"""
nextid(model::ABM) = model.maxid[] + 1

nextid(::FixedMassABM) = error("There is no `nextid` in a `FixedMassABM`. Most likely an internal error.")

"""
    model.prop
    getproperty(model::ABM, :prop)

Return a property with name `:prop` from the current `model`, assuming the model `properties`
are either a dictionary with key type `Symbol` or a Julia struct.
For example, if a model has the set of properties `Dict(:weight => 5, :current => false)`,
retrieving these values can be obtained via `model.weight`.

The property names `:agents, :space, :scheduler, :properties, :maxid` are internals
and **should not be accessed by the user**.
"""
function Base.getproperty(m::ABM{S,A,C,F,P,R}, s::Symbol) where {S,A,C,F,P,R}
    if s === :agents
        return getfield(m, :agents)
    elseif s === :space
        return getfield(m, :space)
    elseif s === :scheduler
        return getfield(m, :scheduler)
    elseif s === :properties
        return getfield(m, :properties)
    elseif s === :rng
        return getfield(m, :rng)
    elseif s === :maxid
        return getfield(m, :maxid)
    elseif P <: Dict
        return getindex(getfield(m, :properties), s)
    else # properties is assumed to be a struct
        return getproperty(getfield(m, :properties), s)
    end
end

function Base.setproperty!(m::ABM{S,A,C,F,P,R}, s::Symbol, x) where {S,A,C,F,P,R}
    exception = ErrorException("Cannot set $(s) in this manner. Please use the `AgentBasedModel` constructor.")
    properties = getfield(m, :properties)
    properties === nothing && throw(exception)
    if P <: Dict && haskey(properties, s)
        properties[s] = x
    elseif hasproperty(properties, s)
        setproperty!(properties, s, x)
    else
        throw(exception)
    end
end

"""
    seed!(model [, seed])

Reseed the random number pool of the model with the given seed or a random one,
when using a pseudo-random number generator like `MersenneTwister`.
"""
function seed!(model::ABM{S,A,C,F,P,R}, args...) where {S,A,C,F,P,R}
    rng = getfield(model, :rng)
    Random.seed!(rng, args...)
end

"""
    random_agent(model) → agent
Return a random agent from the model.
"""
random_agent(model) = model[rand(model.rng, allids(model))]

"""
    random_agent(model, condition) → agent
Return a random agent from the model that satisfies `condition(agent) == true`.
The function generates a random permutation of agent IDs and iterates through them.
If no agent satisfies the condition, `nothing` is returned instead.
"""
function random_agent(model, condition)
    ids = shuffle!(model.rng, collect(allids(model)))
    i, L = 1, length(ids)
    a = model[ids[1]]
    while !condition(a)
        i += 1
        i > L && return nothing
        a = model[ids[i]]
    end
    return a
end

"""
    nagents(model::ABM)
Return the number of agents in the `model`.
"""
nagents(model::ABM) = length(model.agents)

"""
    allagents(model)
Return an iterator over all agents of the model.
"""
allagents(model) = values(model.agents)

"""
    allids(model)
Return an iterator over all agent IDs of the model.
"""
allids(model) = eachindex(model.agents)

#######################################################################################
# %% Higher order collections
#######################################################################################
export iter_agent_groups, map_agent_groups, index_mapped_groups

"""
    iter_agent_groups(order::Int, model::ABM; scheduler = Schedulers.by_id)

Return an iterator over all agents of the model, grouped by order. When `order = 2`, the
iterator returns agent pairs, e.g `(agent1, agent2)` and when `order = 3`: agent triples,
e.g. `(agent1, agent7, agent8)`. `order` must be larger than `1` but has no upper bound.

Index order is provided by the model scheduler by default,
but can be altered with the `scheduler` keyword.
"""
iter_agent_groups(order::Int, model::ABM; scheduler = model.scheduler) =
    Iterators.product((map(i -> model[i], scheduler(model)) for _ in 1:order)...)

"""
    map_agent_groups(order::Int, f::Function, model::ABM; kwargs...)
    map_agent_groups(order::Int, f::Function, model::ABM, filter::Function; kwargs...)

Applies function `f` to all grouped agents of an [`iter_agent_groups`](@ref) iterator.
`kwargs` are passed to the iterator method.
`f` must take the form `f(NTuple{O,AgentType})`, where the dimension `O` is equal to
`order`.

Optionally, a `filter` function that accepts an iterable and returns a `Bool` can be
applied to remove unwanted matches from the results. **Note:** This option cannot keep
matrix order, so should be used in conjunction with [`index_mapped_groups`](@ref) to
associate agent ids with the resultant data.
"""
map_agent_groups(order::Int, f::Function, model::ABM; kwargs...) =
    (f(idx) for idx in iter_agent_groups(order, model; kwargs...))
map_agent_groups(order::Int, f::Function, model::ABM, filter::Function; kwargs...) =
    (f(idx) for idx in iter_agent_groups(order, model; kwargs...) if filter(idx))

"""
    index_mapped_groups(order::Int, model::ABM; scheduler = Schedulers.by_id)
    index_mapped_groups(order::Int, model::ABM, filter::Function; scheduler = Schedulers.by_id)
Return an iterable of agent ids in the model, meeting the `filter` criteria if used.
"""
index_mapped_groups(order::Int, model::ABM; scheduler = Schedulers.by_id) =
    Iterators.product((scheduler(model) for _ in 1:order)...)
index_mapped_groups(order::Int, model::ABM, filter::Function; scheduler = Schedulers.by_id) =
    Iterators.filter(filter, Iterators.product((scheduler(model) for _ in 1:order)...))

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
function Base.show(io::IO, abm::ABM{S,A}) where {S,A}
    n = isconcretetype(A) ? nameof(A) : string(A)
    s = "AgentBasedModel with $(nagents(abm)) agents of type $(n)"
    if abm.space === nothing
        s *= "\n space: nothing (no spatial structure)"
    else
        s *= "\n space: $(sprint(show, abm.space))"
    end
    s *= "\n scheduler: $(schedulername(abm.scheduler))"
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

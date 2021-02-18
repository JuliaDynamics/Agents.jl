export ABM, AgentBasedModel

#######################################################################################
# %% Fundamental type definitions
#######################################################################################

abstract type AbstractSpace end
SpaceType = Union{Nothing,AbstractSpace}

abstract type DiscreteSpace <: AbstractSpace end

# This is a collection of valid position types, sometimes used for ambiguity resolution
ValidPos =
    Union{Int,NTuple{N,Int},NTuple{M,<:AbstractFloat},Tuple{Int,Int,Float64}} where {N,M}

struct AgentBasedModel{S<:SpaceType,A<:AbstractAgent,F,P}
    agents::Dict{Int,A}
    space::S
    scheduler::F
    properties::P
    rng::AbstractRNG
    maxid::Base.RefValue{Int64}
end

const ABM = AgentBasedModel

agenttype(::ABM{S,A}) where {S,A} = A
spacetype(::ABM{S}) where {S} = S

"""
    union_types(U)
Return a set of types within a `Union`. Preserves order.
"""
union_types(x::Union) = union_types(x.a, x.b)
union_types(a::Union, b::Type) = (union_types(a)..., b)
union_types(a::Type, b::Type) = (a, b)
union_types(x::Type) = (x,)
# For completeness
union_types(a::Type, b::Union) = (a, union_types(b)...)

"""
    AgentBasedModel(AgentType [, space]; scheduler, properties) → model
Create an agent based model from the given agent type and `space`.
You can provide an agent _instance_ instead of type, and the type will be deduced.
 `ABM` is equivalent with `AgentBasedModel`.

The agents are stored in a dictionary that maps unique ids (integers)
to agents. Use `model[id]` to get the agent with the given `id`.

`space` is a subtype of `AbstractSpace`: [`GraphSpace`](@ref), [`GridSpace`](@ref) or
[`ContinuousSpace`](@ref).
If it is omitted then all agents are virtually in one position and have no spatial structure.

**Note:** Spaces are mutable objects and are not designed to be shared between models.
Create a fresh instance of a space with the same properties if you need to do this.

`properties = nothing` is additional model-level properties (typically a dictionary)
that can be accessed as `model.properties`. However, if `properties` is a dictionary with
key type `Symbol`, or of it is a struct, then the syntax
`model.name` is short hand for `model.properties[:name]` (or `model.properties.name`
for structs).
This syntax can't be used for `name` being `agents, space, scheduler, properties`,
which are the fields of `AgentBasedModel`.

`scheduler = fastest` decides the order with which agents are activated
(see e.g. [`by_id`](@ref) and the scheduler API).

`rng = Random.default_rng()` provides random number generation to the model.
Passing, for example `MersenneTwister(1234)` will initialise with a repeatable random
seed, and `RandomDevice()` will use the system's entropy source (coupled with hardware
like [TrueRNG](https://ubld.it/truerng_v3) will invoke a true random source, rather
than pseudo-random methods like `MersenneTwister`).

Type tests for `AgentType` are done, and by default
warnings are thrown when appropriate. Use keyword `warn=false` to suppress that.
"""
function AgentBasedModel(
    ::Type{A},
    space::S = nothing;
    scheduler::F = fastest,
    properties::P = nothing,
    rng = Random.default_rng(),
    warn = true,
) where {A<:AbstractAgent,S<:SpaceType,F,P}
    agent_validator(A, space, warn)

    agents = Dict{Int,A}()
    return ABM{S,A,F,P}(agents, space, scheduler, properties, rng, Ref(0))
end

function AgentBasedModel(agent::AbstractAgent, args...; kwargs...)
    return ABM(typeof(agent), args...; kwargs...)
end

#######################################################################################
# %% Model accessing api
#######################################################################################
export random_agent, nagents, allagents, allids, nextid

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
**Internal method**, use [`add_agents!`](@ref) instead to actually add an agent.
"""
function Base.setindex!(m::ABM, a::AbstractAgent, id::Int)
    a.id ≠ id &&
    throw(ArgumentError("You are adding an agent to an ID not equal with the agent's ID!"))
    m.agents[id] = a
    m.maxid[] < id && (m.maxid[] += 1)
    return a
end

"""
    nextid(model::ABM) → id
Return a valid `id` for creating a new agent with it.
"""
nextid(model::ABM) = model.maxid[] + 1

"""
    model.prop
    getproperty(model::ABM, prop::Symbol)

Return a property from the current `model`, assuming the model `properties` are either
a dictionary with key type `Symbol` or a Julia struct.
For example, if a model has the set of properties `Dict(:weight => 5, :current => false)`,
retrieving these values can be obtained via `model.weight`.

The property names `:agents, :space, :scheduler, :properties, :maxid` are internals
and **should not be accessed by the user**.
"""
function Base.getproperty(m::ABM{S,A,F,P}, s::Symbol) where {S,A,F,P}
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

function Base.setproperty!(m::ABM{S,A,F,P}, s::Symbol, x) where {S,A,F,P}
    properties = getfield(m, :properties)
    if properties ≠ nothing && haskey(properties, s)
        properties[s] = x
    else
        throw(ErrorException("Cannot set $(s) in this manner. Please use the `AgentBasedModel` constructor."))
    end
end

"""
    random_agent(model) → agent
Return a random agent from the model.
"""
random_agent(model) = model[rand(model.rng, keys(model.agents))]

"""
    random_agent(model, condition) → agent
Return a random agent from the model that satisfies `condition(agent) == true`.
The function generates a random permutation of agent IDs and iterates through them.
If no agent satisfies the condition, `nothing` is returned instead.
"""
function random_agent(model, condition)
    ids = shuffle!(model.rng, collect(keys(model.agents)))
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
allids(model) = keys(model.agents)

#######################################################################################
# %% Model construction validation
#######################################################################################
"""
    agent_validator(agent, space)
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
        warn &&
        @warn "AgentType is not concrete. If your agent is parametrically typed, you're probably seeing this warning because you gave `Agent` instead of `Agent{Float64}` (for example) to this function. You can also create an instance of your agent and pass it to this function. If you want to use `Union` types for mixed agent models, you can silence this warning."
        for type in union_types(A)
            do_checks(type, space, warn)
        end
    end
end

"""
    do_checks(agent, space)
Helper function for `agent_validator`.
"""
function do_checks(::Type{A}, space::S, warn::Bool) where {A<:AbstractAgent,S<:SpaceType}
    if warn
        isbitstype(A) &&
        @warn "AgentType should be mutable. Try adding the `mutable` keyword infront of `struct` in your agent definition."
    end
    (any(isequal(:id), fieldnames(A)) && fieldnames(A)[1] == :id) ||
    throw(ArgumentError("First field of Agent struct must be `id` (it should be of type `Int`)."))
    fieldtype(A, :id) <: Integer ||
    throw(ArgumentError("`id` field in Agent struct must be of type `Int`."))
    if space !== nothing
        (any(isequal(:pos), fieldnames(A)) && fieldnames(A)[2] == :pos) ||
        throw(ArgumentError("Second field of Agent struct must be `pos` when using a space."))
        # Check `pos` field in A has the correct type
        pos_type = fieldtype(A, :pos)
        space_type = typeof(space)
        if space_type <: GraphSpace && !(pos_type <: Integer)
            throw(ArgumentError("`pos` field in Agent struct must be of type `Int` when using GraphSpace."))
        elseif space_type <: GridSpace && !(pos_type <: NTuple{D,Integer} where {D})
            throw(ArgumentError("`pos` field in Agent struct must be of type `NTuple{Int}` when using GridSpace."))
        elseif space_type <: ContinuousSpace || space_type <: ContinuousSpace
            if !(pos_type <: NTuple{D,<:AbstractFloat} where {D})
                throw(ArgumentError("`pos` field in Agent struct must be of type `NTuple{<:AbstractFloat}` when using ContinuousSpace."))
            end
            if warn &&
               any(isequal(:vel), fieldnames(A)) &&
               !(fieldtype(A, :vel) <: NTuple{D,<:AbstractFloat} where {D})
                @warn "`vel` field in Agent struct should be of type `NTuple{<:AbstractFloat}` when using ContinuousSpace."
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
        s *= "\n no space"
    else
        s *= "\n space: $(sprint(show, abm.space))"
    end
    s *= "\n scheduler: $(schedulername(abm.scheduler))"
    print(io, s)
    if abm.properties ≠ nothing
        print(io, "\n properties: ", abm.properties)
    end
end
schedulername(x::Union{Function,DataType}) = nameof(x)

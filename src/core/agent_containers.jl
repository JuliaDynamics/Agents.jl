export AgentWrapperSoA, construct_agent_container, ContainerType, SoAType

"""
    ContainerType{A}

Union type representing the possible container types for storing agents.
"""
ContainerType{A} = Union{AbstractDict{Int,A},AbstractVector{A}}

"""
    struct AgentWrapperSoA{C} <: AbstractAgent

Wrapper type for agents in a StructVector container.
"""
struct AgentWrapperSoA{A<:AbstractAgent, C} <: AbstractAgent
    soa::C
    id::Int
    agent_type::Type{A}
end

function AgentWrapperSoA{A}(soa::C, id::Int, ::Type{A}) where {A<:AbstractAgent, C}
    return AgentWrapperSoA{A,C}(soa, id, A)
end

const SoAType = AgentWrapperSoA

function Base.getproperty(agent::AgentWrapperSoA, name::Symbol)
    return getproperty(getfield(agent, :soa), name)[getfield(agent, :id)]
end

function Base.setproperty!(agent::AgentWrapperSoA, name::Symbol, x)
    getproperty(getfield(agent, :soa), name)[getfield(agent, :id)] = x
    return agent
end

"""
    agent_container_type(container::Type, A)

Returns the container type for storing agents of type `A` in the specified container type `container`.
"""
agent_container_type(::Type{T}, A) where {T<:AbstractDict} = T{Int,A}
agent_container_type(::Type{T}, A) where {T<:AbstractVector} = T{A}
agent_container_type(container, A) = throw(
    ArgumentError("Unrecognised container $container, please specify `Dict`, `Vector` or `StructVector`.")
)

function construct_agent_container(container::Type, A)
    C = agent_container_type(container, A)
    if C <: StructVector
        init = NamedTuple(name => T[] for (name, T) in zip(fieldnames(A), fieldtypes(A)))
        return C(init)
    else
        return C()
    end
end
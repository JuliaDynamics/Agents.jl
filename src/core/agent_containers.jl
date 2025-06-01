export SoAType

"""
    AgentWrapperSoA <: AbstractAgent

Wrapper type for agents in a StructVector container.
"""
struct AgentWrapperSoA{A, C} <: AbstractAgent
    soa::C
    id::Int
end

"""
`SoAType` is a type alias for `AgentWrapperSoA`.

This alias is provided for convenience and to improve code readability.
"""
const SoAType = AgentWrapperSoA

function AgentWrapperSoA{A}(soa::C, id::Int) where {A<:AbstractAgent, C}
    return AgentWrapperSoA{A,C}(soa, id)
end

function Base.getproperty(agent::AgentWrapperSoA, name::Symbol)
    return getproperty(getfield(agent, :soa), name)[getfield(agent, :id)]
end

function Base.setproperty!(agent::AgentWrapperSoA, name::Symbol, x)
    getproperty(getfield(agent, :soa), name)[getfield(agent, :id)] = x
    return agent
end

"""
    agent_container_type(container::Type, A)

Return the container type for storing agents of type `A` in the specified container type `container`.
"""
agent_container_type(::Type{T}, A) where {T<:AbstractDict} = T{Int,A}
agent_container_type(::Type{T}, A) where {T<:AbstractVector} = T{A}
agent_container_type(container, A) = throw(
    ArgumentError("Unrecognised container $container, please provide a valid container type")
)

"""
    construct_agent_container(container::Type, A)

Construct and return an instance of the agent container type using the specified `container` type.
"""
function construct_agent_container(container::Type, A)
    C = agent_container_type(container, A)
    if C <: StructVector
        init = NamedTuple(name => T[] for (name, T) in zip(fieldnames(A), fieldtypes(A)))
        return C(init)
    else
        return C()
    end
end

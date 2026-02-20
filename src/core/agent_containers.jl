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
    SoAType{A} <: AbstractAgent

Wrapper type for agents of type `A` in a model containing a `StructVector` container.

This is needed for specializing signatures involving `A` e.g. instead of writing `agent_step!(agent::A, model)`,
in the case of a model with a `StructVector` container, you should write `agent_step!(agent::SoaType{A}, model)`
since `model[id]` is a `SoaType{A}`.
"""
const SoAType = AgentWrapperSoA

function AgentWrapperSoA{A}(soa::C, id::Int) where {A <: AbstractAgent, C}
    return AgentWrapperSoA{A, C}(soa, id)
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
agent_container_type(::Type{T}, A) where {T <: AbstractDict} = T{Int, A}
agent_container_type(::Type{T}, A) where {T <: AbstractVector} = T{A}
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

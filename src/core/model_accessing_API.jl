const DictABM = Union{StandardABM{S,A,<:AbstractDict{<:Integer,A}} where {S,A},
    EventQueueABM{S,A,<:AbstractDict{<:Integer,A}} where {S,A},
    ReinforcementLearningABM{S,A,<:AbstractDict{<:Integer,A}} where {S,A}}
const VecABM = Union{StandardABM{S,A,<:AbstractVector{A}} where {S,A},
    EventQueueABM{S,A,<:AbstractVector{A}} where {S,A},
    ReinforcementLearningABM{S,A,<:AbstractVector{A}} where {S,A}}
const StructVecABM = Union{StandardABM{S,A,<:StructVector{A}} where {S,A},
    EventQueueABM{S,A,<:StructVector{A}} where {S,A},
    ReinforcementLearningABM{S,A,<:StructVector{A}} where {S,A}}

nextid(model::DictABM) = getfield(model, :maxid)[] + 1
nextid(model::Union{VecABM, StructVecABM}) = nagents(model) + 1
hasid(model::Union{VecABM, StructVecABM}, id::Int) = id ≤ nagents(model)

function add_agent_to_container!(agent::AbstractAgent, container::AbstractDict)
    if haskey(container, getid(agent))
        error(lazy"Can't add agent to container. There is already an agent with id=$(getid(agent))")
    else
        container[getid(agent)] = agent
    end
end

function add_agent_to_container!(agent::AbstractAgent, container::AbstractVector)
    getid(agent) != length(container) + 1 && error(lazy"Cannot add agent of ID $(getid(agent)) in a vector container of $(length(container)) agents. Expected ID == $(length(container)+1).")
    push!(container, agent)
end

function add_agent_to_container!(agent::AbstractAgent, model::ABM)
    add_agent_to_container!(agent, agent_container(model))
    # Update maxid for DictABM
    if model isa DictABM
        maxid = getfield(model, :maxid)
        if maxid[] < getid(agent)
            maxid[] = getid(agent)
        end
    end
    return
end

# This is extended for event based models
extra_actions_after_add!(agent, model::StandardABM) = nothing
function extra_actions_after_add!(agent, model::EventQueueABM{S,A,<:Union{AbstractDict, AbstractVector}} where {S,A})
    getfield(model, :autogenerate_on_add) && add_event!(agent, model)
end
function extra_actions_after_add!(agent, model::EventQueueABM{S,A,<:StructVector} where {S,A})
    getfield(model, :autogenerate_on_add) && add_event!(model[getid(agent)], model)
end
extra_actions_after_add!(agent, model::ReinforcementLearningABM) = nothing

function remove_agent_from_container!(agent::AbstractAgent, model::DictABM)
    delete!(agent_container(model), getid(agent))
    return
end
function remove_agent_from_container!(agent::AbstractAgent, model::Union{VecABM, StructVecABM})
    error("Cannot remove agents in a `StandardABM` with a vector container.")
end

# Internal utility for retrieving agents by id from a container
retrieve_agent(container::StructVector, id::Int, ::Type{A}) where {A} = AgentWrapperSoA{A}(container, id)
retrieve_agent(container, id::Int, ::Type) = container[id]

random_id(model::DictABM) = rand(abmrng(model), agent_container(model)).first
random_agent(model::DictABM) = rand(abmrng(model), agent_container(model)).second

getid(agent) = agent.id

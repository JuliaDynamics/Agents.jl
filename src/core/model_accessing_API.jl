const DictABM = Union{StandardABM{S,A,<:AbstractDict{<:Integer,A}} where {S,A},
                      EventQueueABM{S,A,<:AbstractDict{<:Integer,A}} where {S,A}}
const VecABM = Union{StandardABM{S,A,<:AbstractVector{A}} where {S,A},
                     EventQueueABM{S,A,<:AbstractVector{A}} where {S,A}}
const StructVecABM = Union{StandardABM{S,A,<:StructVector{A}} where {S,A},
                         EventQueueABM{S,A,<:StructVector{A}} where {S,A}}

nextid(model::DictABM) = getfield(model, :maxid)[] + 1
nextid(model::Union{VecABM, StructVecABM}) = nagents(model) + 1
hasid(model::Union{VecABM, StructVecABM}, id::Int) = id ≤ nagents(model)

function add_agent_to_container!(agent::AbstractAgent, model::DictABM)
    if haskey(agent_container(model), agent.id)
        error(lazy"Can't add agent to model. There is already an agent with id=$(agent.id)")
    else
        agent_container(model)[agent.id] = agent
    end
    maxid = getfield(model, :maxid)
    new_id = agent.id
    if maxid[] < new_id; maxid[] = new_id; end
    return
end

function add_agent_to_container!(agent::AbstractAgent, model::Union{VecABM, StructVecABM})
    agent.id != nagents(model) + 1 && error(lazy"Cannot add agent of ID $(agent.id) in a vector ABM of $(nagents(model)) agents. Expected ID == $(nagents(model)+1).")
    push!(agent_container(model), agent)
    return
end

# This is extended for event based models
extra_actions_after_add!(agent, model::StandardABM) = nothing
function extra_actions_after_add!(agent, model::EventQueueABM{S,A,<:Union{AbstractDict, AbstractVector}} where {S,A})
    getfield(model, :autogenerate_on_add) && add_event!(agent, model)
end
function extra_actions_after_add!(agent, model::EventQueueABM{S,A,<:StructVector} where {S,A})
    getfield(model, :autogenerate_on_add) && add_event!(model[agent.id], model)
end

function remove_agent_from_container!(agent::AbstractAgent, model::DictABM)
    delete!(agent_container(model), agent.id)
    return
end
function remove_agent_from_container!(agent::AbstractAgent, model::Union{VecABM, StructVecABM})
    error("Cannot remove agents in a `StandardABM` with a vector container.")
end

random_id(model::DictABM) = rand(abmrng(model), agent_container(model)).first
random_agent(model::DictABM) = rand(abmrng(model), agent_container(model)).second

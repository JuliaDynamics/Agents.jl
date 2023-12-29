
const DictABM = Union{StandardABM{S,A,Dict{Int,A}} where {S,A},
                      EventQueueABM{S,A,Dict{Int,A}} where {S,A}}
const VecABM = Union{StandardABM{S,A,Vector{A}} where {S,A},
                     EventQueueABM{S,A,Vector{A}} where {S,A}}

nextid(model::DictABM) = getfield(model, :maxid)[] + 1
nextid(model::VecABM) = nagents(model) + 1

function add_agent_to_model!(agent::AbstractAgent, model::DictABM)
    if haskey(agent_container(model), agent.id)
        error("Can't add agent to model. There is already an agent with id=$(agent.id)")
    else
        agent_container(model)[agent.id] = agent
    end
    maxid = getfield(model, :maxid)
    new_id = agent.id
    if maxid[] < new_id; maxid[] = new_id; end
    extra_actions_after_add!(agent, model)
    return
end

function add_agent_to_model!(agent::AbstractAgent, model::VecABM)
    agent.id != nagents(model) + 1 && error("Cannot add agent of ID $(agent.id) in a vector ABM of $(nagents(model)) agents. Expected ID == $(nagents(model)+1).")
    push!(agent_container(model), agent)
    extra_actions_after_add!(agent, model)
    return
end

# This is extended for event based models (in their file)
extra_actions_after_add!(agent, model::StandardABM) = nothing

function remove_agent_from_model!(agent::AbstractAgent, model::DictABM)
    delete!(agent_container(model), agent.id)
    return
end

function remove_agent_from_model!(agent::AbstractAgent, model::VecABM)
    error("Cannot remove agents in a `StandardABM` with a vector container.")
end

random_id(model::DictABM) = rand(abmrng(model), agent_container(model)).first
random_agent(model::DictABM) = rand(abmrng(model), agent_container(model)).second
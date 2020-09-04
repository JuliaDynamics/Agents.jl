using Random

mutable struct Citizen <: AbstractAgent
	id::Int
	pos::Tuple{Int, Int}
	stabilized::Bool
	opinion::Array{Int, 1}
	prev_opinion::Array{Int, 1}
end

"""
    opinion(;dims=(10, 10), nopinions=3, levels_per_opinion=4)

Same as in [Opinion spread model](@ref).
"""
function opinion(;dims=(10, 10), nopinions=3, levels_per_opinion=4)
	space = GridSpace(dims, periodic=true, moore=true)
	properties = Dict(:nopinions=>nopinions) 
	model = AgentBasedModel(Citizen, space, scheduler=random_activation, properties=properties)
	for cell in 1:nv(model)
		add_agent!(cell, model, false, rand(1:levels_per_opinion, nopinions), rand(1:levels_per_opinion, nopinions))
	end
	return model, opinion_agent_step!
end

function adopt!(agent, model)
	neighbor = rand(space_neighbors(agent, model))
	matches = model[neighbor].opinion .== agent.opinion
	nmatches = count(matches)
	# Adopt a different opinion w/ calculated probability
	if nmatches < model.nopinions && rand() < nmatches/model.nopinions
		switchId = rand(findall(x-> x==false, matches))
		agent.opinion[switchId] = model[neighbor].opinion[switchId]
	end
end

function update_prev_opinion!(agent, model)
	for i in 1:model.nopinions
		agent.prev_opinion[i] = agent.opinion[i]
	end
end

function is_stabilized!(agent, model)
	if agent.prev_opinion == agent.opinion
		agent.stabilized = true
	else
		agent.stabilized = false
	end
end

function opinion_agent_step!(agent, model)
	update_prev_opinion!(agent, model)
	adopt!(agent, model)
	is_stabilized!(agent, model)
end

# # Opinion spread

# ![](opinion.gif)

# This is a simple model of how an opinion spreads through a community.
# Each individual has a number of opinions as a list of integers.
# They can change their opinion by changing the numbers in the list.

# Agents can change their opinion at each step.
# They choose one of their neighbors randomly, and adopt one of the neighbor's opinion.
# They are more likely to adopt their neighbors opinion if the share more opinions with each other.

using Agents
using AgentsPlots
using Random

# ## Building the model
# ### 1. Model creation

mutable struct Citizen <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    stabilized::Bool
    opinion::Array{Int,1}
    prev_opinion::Array{Int,1}
end

function create_model(; dims = (10, 10), nopinions = 3, levels_per_opinion = 4)
    space = GridSpace(dims)
    properties = Dict(:nopinions => nopinions)
    model = AgentBasedModel(
        Citizen,
        space,
        scheduler = random_activation,
        properties = properties,
    )
    for pos in positions(model)
        add_agent!(
            pos,
            model,
            false,
            rand(1:levels_per_opinion, nopinions),
            rand(1:levels_per_opinion, nopinions),
        )
    end
    return model
end

# ### 2. Stepping functions

function adopt!(agent, model)
    neighbor = rand(collect(nearby_ids(agent, model)))
    matches = model[neighbor].opinion .== agent.opinion
    nmatches = count(matches)
    if nmatches < model.nopinions && rand() < nmatches / model.nopinions
        switchId = rand(findall(x -> x == false, matches))
        agent.opinion[switchId] = model[neighbor].opinion[switchId]
    end
end

function update_prev_opinion!(agent, model)
    for i in 1:(model.nopinions)
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

function agent_step!(agent, model)
    update_prev_opinion!(agent, model)
    adopt!(agent, model)
    is_stabilized!(agent, model)
end

# ## Running the model

levels_per_opinion = 4
model = create_model(nopinions = 3, levels_per_opinion = levels_per_opinion)

"run the model until all agents stabilize"
rununtil(model, s) = count(a->a.stabilized, allagents(model)) == length(positions(model))

agentdata, _ = run!(model, agent_step!, dummystep, rununtil, adata = [(:stabilized, count)])

# ## Plotting

# The plot shows the number of stable agents, that is, number of agents whose opinions
# don't change from one step to the next. Note that the number of stable agents can 
# fluctuate before the final convergence.

plot(
    1:size(agentdata, 1),
    agentdata.count_stabilized,
    legend = false,
    xlabel = "generation",
    ylabel = "# of stabilized agents",
)

# ### Animation

# Here is an animation that shows change of agent opinions over time.
# The first three opinions of an agent determines its color in RGB.
levels_per_opinion = 3
ac(agent) = RGB((agent.opinion[1:3] ./ levels_per_opinion)...)
model = create_model(nopinions = 3, levels_per_opinion = levels_per_opinion)
anim = @animate for sp in 1:500
    step!(model, agent_step!)
    p = plotabm(model, ac = ac, as = 12, am = :square)
    title!(p, "Step $(sp)")
    if rununtil(model, 1)
        break
    end
end
gif(anim, "opinion.gif")


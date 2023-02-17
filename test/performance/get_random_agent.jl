using Agents, Random, BenchmarkTools
using Agents: optimistic_random_agent, allocating_random_agent

mutable struct LabelledAgent <: AbstractAgent
    id::Int
    label::Bool
end

n_agents = 100
agents = [LabelledAgent(id, id<=n_agents/100) for id in 1:n_agents]
noremove_model = UnkillableABM(LabelledAgent)
dict_model = ABM(LabelledAgent)
fixed_model = FixedMassABM(agents)
for a in agents
    add_agent!(a, dict_model)
    add_agent!(a, noremove_model)
end

cond(agent) = agent.label

# All times are median
# FixedMassABM
@benchmark optimistic_random_agent(fixed_model, cond)
@benchmark allocating_random_agent(fixed_model, cond)

# UnkillableABM
@benchmark optimistic_random_agent(noremove_model, cond)
@benchmark allocating_random_agent(noremove_model, cond)

# DictionaryABM
@benchmark optimistic_random_agent(dict_model, cond)
@benchmark allocating_random_agent(dict_model, cond)
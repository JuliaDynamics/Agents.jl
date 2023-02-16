using Agents, Random, BenchmarkTools
using Agents: optimistic_random_agent, allocating_random_agent, allocating_random_agent2

mutable struct LabelledAgent <: AbstractAgent
    id::Int
    label::Bool
end

n_agents = 100
agents = [LabelledAgent(id, id>n_agents/2) for id in 1:n_agents]
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
@benchmark optimistic_random_agent(fixed_model, cond) # 336 ns
@benchmark allocating_random_agent(fixed_model, cond) # 1450 ns
@benchmark allocating_random_agent2(fixed_model, cond) # 6100 ns

# UnkillableABM
@benchmark optimistic_random_agent(noremove_model, cond) # 158 ns 
@benchmark allocating_random_agent(noremove_model, cond) # 1283 ns
@benchmark allocating_random_agent2(noremove_model, cond) # 276 ns

# DictionaryABM
@benchmark optimistic_random_agent(dict_model, cond) # 454 ns
@benchmark allocating_random_agent(dict_model, cond) # 1592 ns
@benchmark allocating_random_agent2(dict_model, cond) # 882 ns
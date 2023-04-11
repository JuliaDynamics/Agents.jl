using Agents, Random, BenchmarkTools

mutable struct LabelledAgent <: AbstractAgent
    id::Int
    label::Bool
end

n_agents = 100
agents = [LabelledAgent(id, id<=n_agents/3) for id in 1:n_agents]
noremove_model = UnremovableABM(LabelledAgent)
dict_model = ABM(LabelledAgent)

for a in agents
    add_agent!(a, dict_model)
    add_agent!(a, noremove_model)
end

cond(agent) = agent.label

function old_random_agent(model, condition)
    ids = shuffle!(abmrng(model), collect(allids(model)))
    i, L = 1, length(ids)
    a = model[ids[1]]
    while !condition(a)
        i += 1
        i > L && return nothing
        a = model[ids[i]]
    end
    return a
end

# All times are median

# UnremovableABM
@benchmark random_agent($noremove_model, $cond, optimistic=true)
@benchmark random_agent($noremove_model, $cond, optimistic=false)
@benchmark old_random_agent($noremove_model, $cond)

# DictionaryABM
@benchmark random_agent($noremove_model, $cond, optimistic=true)
@benchmark random_agent($noremove_model, $cond, optimistic=false)
@benchmark old_random_agent($noremove_model, $cond)

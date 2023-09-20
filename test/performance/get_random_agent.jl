using Agents, Random, BenchmarkTools

@agent struct LabelledAgent(NoSpaceAgent)
    label::Bool
end

function create_model(ModelType, n_agents_with_condition, n_agents=1000)
    model = ModelType(LabelledAgent)
    for id in 1:n_agents
        add_agent!(LabelledAgent, model, id<=n_agents_with_condition)
    end
    return model
end

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

cond(agent) = agent.label

# common condition

# UnremovableABM
@benchmark random_agent(model, $cond, optimistic=true) setup=(model=create_model(UnremovableABM, 200))
@benchmark random_agent(model, $cond, optimistic=false) setup=(model=create_model(UnremovableABM, 200))
@benchmark old_random_agent(model, $cond) setup=(model=create_model(UnremovableABM, 200))

# DictionaryABM
@benchmark random_agent(model, $cond, optimistic=true) setup=(model=create_model(StandardABM, 200))
@benchmark random_agent(model, $cond, optimistic=false) setup=(model=create_model(StandardABM, 200))
@benchmark old_random_agent(model, $cond) setup=(model=create_model(StandardABM, 200))

# rare condition

# UnremovableABM
@benchmark random_agent(model, $cond, optimistic=true) setup=(model=create_model(UnremovableABM, 2))
@benchmark random_agent(model, $cond, optimistic=false) setup=(model=create_model(UnremovableABM, 2))
@benchmark old_random_agent(model, $cond) setup=(model=create_model(UnremovableABM, 2))

# DictionaryABM
@benchmark random_agent(model, $cond, optimistic=true) setup=(model=create_model(StandardABM, 2))
@benchmark random_agent(model, $cond, optimistic=false) setup=(model=create_model(StandardABM, 2))
@benchmark old_random_agent(model, $cond) setup=(model=create_model(StandardABM, 2))

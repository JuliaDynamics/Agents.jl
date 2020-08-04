using StatsBase: mean

mutable struct HKAgent <: AbstractAgent
    id::Int
    old_opinion::Float64
    new_opinion::Float64
    previous_opinon::Float64
end

"""
``` julia
HK(; 
    numagents = 100, 
    ϵ = 0.2
)
```
Same as in [HK (Hegselmann and Krause) opinion dynamics model](@ref).
"""
function HK(; numagents = 100, ϵ = 0.2)
    model = ABM(HKAgent, scheduler = fastest, properties = Dict(:ϵ => ϵ))
    for i in 1:numagents
        o = rand()
        add_agent!(model, o, o, -1)
    end
    return model, HK_agent_step!, HK_model_step!, terminate
end

function boundfilter(agent, model)
    filter(
        j -> abs(agent.old_opinion - j) < model.ϵ,
        [a.old_opinion for a in allagents(model)],
    )
end

function HK_agent_step!(agent, model)
    agent.previous_opinon = agent.old_opinion
    agent.new_opinion = mean(boundfilter(agent, model))
end

function HK_model_step!(model)
    for a in allagents(model)
        a.old_opinion = a.new_opinion
    end
end

function terminate(model, s)
    if any(
        !isapprox(a.previous_opinon, a.new_opinion; rtol = 1e-12) for a in allagents(model)
    )
        return false
    else
        return true
    end
end

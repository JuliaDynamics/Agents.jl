# Visually inspect CompartmentSpace `nearby_ids`
using Agents
using AgentsPlots

mutable struct Ag <: AbstractAgent
    id::Int
    pos::NTuple{2,Float64}
end

s = CompartmentSpace((10, 10), 0.5)
model = ABM(Ag, s)
for i in 1:800
    add_agent!(model)
end

global r = 1.4
global agentid = 299
function ac(a)
    if a.id == agentid
        return :red
    elseif a.id in nearby_ids(model[agentid], model, r, exact=true)
        return :blue
    else
        return :yellow
    end
end
plotabm(model, as=2.5, ac=ac, grid= (:both, :dot, 1, 0.9), xticks=1:20, yticks=1:20)
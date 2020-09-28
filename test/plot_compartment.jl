# Visually inspect CompartmentSpace `nearby_ids`
using Agents
using AgentsPlots
# using Plots

mutable struct Ag <: AbstractAgent
    id::Int
    pos::NTuple{2,Float64}
end

s = CompartmentSpace((10, 10), 0.5)
model = ABM(Ag, s)
for i in 1:800
    add_agent!(model)
end

r = 1.4
agentid = rand(1:800)
function ac(a)
    if a.id == agentid
        return :red
    elseif a.id in nearby_ids(model[agentid], model, r, exact=true)
        return :blue
    else
        return :yellow
    end
end

function circleShape(h, k, r)
    θ = LinRange(0, 2π, 500)
    h .+ r*sin.(θ), k .+ r .* cos.(θ)
end

p = plotabm(model, as=2.5, ac=ac, grid = (:both, :dot, 1, 0.9), xticks=1:20, yticks=1:20)
a = model[agentid]
AgentsPlots.Plots.plot!(p, circleShape(a.pos[1], a.pos[2], r), seriestype = [:shape, ], lw = 0.5,
      c = :blue, linecolor = :black, legend = false, fillalpha = 0.2, aspect_ratio=1)

p

# Visually inspect ContinuousSpace `nearby_ids`
using Agents
using AgentsPlots

mutable struct Ag <: AbstractAgent
    id::Int
    pos::NTuple{2,Float64}
end

ε = 0.2
s = ContinuousSpace((10, 10), ε)
model = ABM(Ag, s)
for i in 1:800
    add_agent!(model)
end

r = 2
function ac(a)
    nids = nearby_ids(model[agentid], model, r, exact=false)
    if a.id == agentid
        return :red
 elseif a.id in nids
        return :blue
    else
        return :yellow
    end
end

function circleShape(h, k, r)
    θ = LinRange(0, 2π, 500)
    h .+ r*sin.(θ), k .+ r .* cos.(θ)
end

# %% --- INEXACT ---
agentid = rand(1:800)
a = model[agentid]
δ = Agents.distance_from_cell_center(a.pos, model)
grid_r = (r+δ)/model.space.spacing
focal_cell = Agents.pos2cell(a.pos, model)
allcells = Agents.grid_space_neighborhood(CartesianIndex(focal_cell), model, grid_r)
search_region = [(a .* s.spacing) .- (s.spacing/2) for a in allcells]

p = plotabm(model, as=4, ac=ac, grid = (:both, :dot, 1, 0.9), xticks=(0:s.spacing:s.extent[1]), yticks=(0:s.spacing:s.extent[2]), size=(1000, 1000))
scatter!(search_region; markershape=:square, markersize=8, markerstrokewidth = 0, markeralpha = 0.2, markercolor=:grey)

plot!(p, circleShape(a.pos[1], a.pos[2], r), seriestype = :shape, lw = 0.5,
      c = :blue, linecolor = :black, legend = false, fillalpha = 0.2, aspect_ratio=1)
# Add all possible mirrors
plot!(p, circleShape(a.pos[1]-s.extent[1], a.pos[2], r), seriestype = :shape, lw = 0.5,
      c = :blue, linecolor = :black, legend = false, fillalpha = 0.2, aspect_ratio=1)
plot!(p, circleShape(a.pos[1]-s.extent[1], a.pos[2]-s.extent[2], r), seriestype = :shape, lw = 0.5,
      c = :blue, linecolor = :black, legend = false, fillalpha = 0.2, aspect_ratio=1)
plot!(p, circleShape(a.pos[1], a.pos[2]-s.extent[2], r), seriestype = :shape, lw = 0.5,
      c = :blue, linecolor = :black, legend = false, fillalpha = 0.2, aspect_ratio=1)
plot!(p, circleShape(a.pos[1]+s.extent[1], a.pos[2], r), seriestype = :shape, lw = 0.5,
      c = :blue, linecolor = :black, legend = false, fillalpha = 0.2, aspect_ratio=1)
plot!(p, circleShape(a.pos[1]+s.extent[1], a.pos[2]+s.extent[2], r), seriestype = :shape, lw = 0.5,
      c = :blue, linecolor = :black, legend = false, fillalpha = 0.2, aspect_ratio=1)
plot!(p, circleShape(a.pos[1], a.pos[2]+s.extent[2], r), seriestype = :shape, lw = 0.5,
      c = :blue, linecolor = :black, legend = false, fillalpha = 0.2, aspect_ratio=1)
# Truncate view
xlims!(0, s.extent[1])
ylims!(0, s.extent[2])
title!(p, "inexact")


# %% --- EXACT ---
function act(a)
    if a.id == agentid
        return :red
    elseif a.id in nearby_ids(model[agentid], model, r, exact=true)
        return :blue
    else
        return :yellow
    end
end
p = plotabm(model, as=4, ac=act, grid = (:both, :dot, 1, 0.9), xticks=(0:s.spacing:s.extent[1]), yticks=(0:s.spacing:s.extent[2]), size=(1000, 1000))
plot!(p, circleShape(a.pos[1], a.pos[2], r), seriestype = :shape, lw = 0.5,
      c = :blue, linecolor = :black, legend = false, fillalpha = 0.2, aspect_ratio=1)
# Add all possible mirrors
plot!(p, circleShape(a.pos[1]-s.extent[1], a.pos[2], r), seriestype = :shape, lw = 0.5,
      c = :blue, linecolor = :black, legend = false, fillalpha = 0.2, aspect_ratio=1)
plot!(p, circleShape(a.pos[1]-s.extent[1], a.pos[2]-s.extent[2], r), seriestype = :shape, lw = 0.5,
      c = :blue, linecolor = :black, legend = false, fillalpha = 0.2, aspect_ratio=1)
plot!(p, circleShape(a.pos[1], a.pos[2]-s.extent[2], r), seriestype = :shape, lw = 0.5,
      c = :blue, linecolor = :black, legend = false, fillalpha = 0.2, aspect_ratio=1)
plot!(p, circleShape(a.pos[1]+s.extent[1], a.pos[2], r), seriestype = :shape, lw = 0.5,
      c = :blue, linecolor = :black, legend = false, fillalpha = 0.2, aspect_ratio=1)
plot!(p, circleShape(a.pos[1]+s.extent[1], a.pos[2]+s.extent[2], r), seriestype = :shape, lw = 0.5,
      c = :blue, linecolor = :black, legend = false, fillalpha = 0.2, aspect_ratio=1)
plot!(p, circleShape(a.pos[1], a.pos[2]+s.extent[2], r), seriestype = :shape, lw = 0.5,
      c = :blue, linecolor = :black, legend = false, fillalpha = 0.2, aspect_ratio=1)
# Truncate view
xlims!(0, s.extent[1])
ylims!(0, s.extent[2])
title!(p, "exact")

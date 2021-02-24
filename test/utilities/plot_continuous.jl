# Visually inspect ContinuousSpace `nearby_ids`
using Agents
using Plots

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

focal_cell = Agents.pos2cell(a.pos, model)
grid_r_max = r < model.space.spacing ? 1.0 : r / model.space.spacing + 1
allcells = Agents.grid_space_neighborhood(CartesianIndex(focal_cell), model, grid_r_max)
search_region = [(a .* s.spacing) .- (s.spacing/2) for a in allcells]
scatter!(p, search_region; markershape=:square, markersize=8, markerstrokewidth = 0, markeralpha = 0.2, markercolor=:grey)

grid_r_certain = grid_r_max - 1.2*sqrt(2)
certain_cells = Agents.grid_space_neighborhood(CartesianIndex(focal_cell), model, grid_r_certain)
search_region = [(a .* s.spacing) .- (s.spacing/2) for a in certain_cells]
scatter!(p, search_region; markershape=:diamond, markersize=8, markerstrokewidth = 0, markeralpha = 0.2, markercolor=:green)

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


# 3D

mutable struct Ag3<: AbstractAgent
    id::Int
    pos::NTuple{3,Float64}
end
ε = 1.0
s = ContinuousSpace((10, 10, 10), ε)
model = ABM(Ag3, s)
for i in 1:800
    add_agent!(model)
end

function Sphere(O, r)
N = 32
u = LinRange(0, 2π, N)
v = LinRange(0, π, N)
x = cos.(u) * sin.(v)'
y = sin.(u) * sin.(v)'
z = repeat(cos.(v)',outer=[N, 1])
(x.*r.+O[1],y.*r.+O[2],z.*r.+O[3])
end

r = 2
agentid = rand(1:800)
a = model[agentid]
δ = Agents.distance_from_cell_center(a.pos, model)
grid_r = (r+δ)/model.space.spacing
focal_cell = Agents.pos2cell(a.pos, model)
allcells = Agents.grid_space_neighborhood(CartesianIndex(focal_cell), model, grid_r)
search_region = [(a .* s.spacing) .- (s.spacing/2) for a in allcells]

p = plotabm(model, as=4, ac=act,
            grid = (:both, :dot, 1, 0.9), xticks=(0:s.spacing:s.extent[1]), yticks=(0:s.spacing:s.extent[2]), zticks=(0:s.spacing:s.extent[3]),
            size=(1000, 1000, 1000))
#scatter!(search_region; markershape=:square, markersize=8, markerstrokewidth = 0, markeralpha = 0.2, markercolor=:grey)

plot!(p, Sphere(a.pos, r), seriestype = :shape, lw = 0.5,
      c = :blue, linecolor = :black, legend = false, fillalpha = 0.2, aspect_ratio=1)
# Truncate view
xlims!(0, s.extent[1])
ylims!(0, s.extent[2])
zlims!(0, s.extent[3])


plot!(p, camera=(20,50))

plot!(p, camera=(0,90))

plot!(p, camera=(90,0))

plot!(p, camera=(50,50))


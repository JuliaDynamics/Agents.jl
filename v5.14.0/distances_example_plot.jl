using CairoMakie
fig = Figure(resolution = (850, 300))

function circle!(ax, r, color, distance)
    if distance == :euclidean
        θ = 0:0.01:2π
        lines!(ax, r .* cos.(θ), r .* sin.(θ); color)
    elseif distance == :chebyshev
        lines!(ax, [-r, -r], [-r, r]; color)
        lines!(ax, [-r, r], [r, r]; color)
        lines!(ax, [r, r], [r, -r]; color)
        lines!(ax, [-r, r], [-r, -r]; color)
    elseif distance == :manhattan
        lines!(ax, [-r, 0], [0, r]; color)
        lines!(ax, [0, r], [r, 0]; color)
        lines!(ax, [r, 0], [0, -r]; color)
        lines!(ax, [0, -r], [-r, 0]; color)
    end
end

function scatter_dots!(ax, r)
    r0 = ceil(r)
    X = -r0:r0
    points = [Point2f(x, y) for x in X for y in X]
    scatter!(ax, points; color = :black)
end

rs = [1, 2, 3.4]
colors = [:blue, :red, :orange]

for (i, distance) in enumerate((:euclidean, :chebyshev, :manhattan))
    ax = Axis(fig[1, i]; title = string(distance))
    scatter_dots!(ax, maximum(rs))
    for (j, r) in enumerate(rs)
        label = j == i ? "r = $(r)" : ""
        circle!(ax, r, colors[j], distance)
    end
    ax.xticks = ax.yticks = -4:2:4
    i > 1 && hideydecorations!(ax; grid = false)
end

elems = [LineElement(color = c, linestyle = nothing) for c in colors]

fig[1, 4] = Legend(fig[1,4], elems, string.(rs), "radius", framevisible = false)

fig
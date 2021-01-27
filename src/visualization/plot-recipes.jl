using RecipesBase
using GraphRecipes

export plotabm, plotabm!

mutable struct PlotABM{AbstractSpace}
    args::Any
end

plotabm(args...; kw...) = RecipesBase.plot(PlotABM{typeof(args[1].space)}(args); kw...)
plotabm!(args...; kw...) = RecipesBase.plot!(PlotABM{typeof(args[1].space)}(args); kw...)
plotabm!(plt::RecipesBase.AbstractPlot, args...; kw...) =
    RecipesBase.plot!(plt, PlotABM{typeof(args[1].space)}(args); kw...)

@recipe function f(
    h::PlotABM{<:Union{GridSpace,ContinuousSpace}};
    scheduler = nothing,
    offset = nothing,
    ac = "#765db4",
    as = 10,
    am = :circle,
)
    if length(h.args) != 1 || !(typeof(h.args[1]) <: ABM)
        error("plotabm should be given a model::ABM.  Got: $(typeof(h.args))")
    end

    model = h.args[1]
    if scheduler == nothing
        scheduler = model.scheduler
    end

    ids = scheduler(model)
    colors = typeof(ac) <: Function ? [ac(model[i]) for i in ids] : ac
    sizes = typeof(as) <: Function ? [as(model[i]) for i in ids] : as
    markers = typeof(am) <: Function ? [am(model[i]) for i in ids] : am

    if offset == nothing
        pos = [model[i].pos for i in ids]
    else
        pos = [model[i].pos .+ offset(model[i]) for i in ids]
    end
    x := first.(pos)
    y := last.(pos)

    seriestype := :scatter
    markercolor := colors
    markersize := sizes
    markershape := markers
    legend --> false
    markerstrokewidth --> 0.5
    markerstrokecolor --> :black
    ()
end

@recipe function f(
    h::PlotABM{<:GraphSpace};
    ac = x -> "#765db4",
    as = length,
    am = x -> :circle,
)
    if length(h.args) != 1 || !(typeof(h.args[1]) <: ABM)
        error("plotabm should be given a model::ABM.  Got: $(typeof(h.args))")
    end
    model = h.args[1]
    N = nodes(model)
    ncolor = Vector(undef, length(N))
    weights = zeros(length(N))
    markers = Vector(undef, length(N))
    for (i, n) in enumerate(N)
        a = get_node_agents(n, model)
        ncolor[i] = ac(a)
        weights[i] = as(a)
        markers[i] = am(a)
    end

    node_weights := weights
    nodeshape := markers
    nodecolor := ncolor
    seriescolor --> :black
    markerstrokecolor --> :black
    markerstrokewidth --> 1.5
    model.space.graph
end

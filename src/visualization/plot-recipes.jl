using RecipesBase
using GraphRecipes

export plotabm, plotabm!

mutable struct PlotABM{AbstractSpace}
    args::Any
end

"""
    plotabm(model::ABM{<: ContinuousSpace}; ac, as, am, kwargs...)
    plotabm(model::ABM{<: DiscreteSpace}; ac, as, am, kwargs...)

Plot the `model` as a `scatter`-plot, by configuring the agent shape, color and size
via the keywords `ac, as, am`.
These keywords can be constants, or they can be functions, each accepting an agent
and outputting a valid value for color/shape/size.

The keyword `scheduler = model.scheduler` decides the plotting order of agents
(which matters only if there is overlap).

The keyword `offset` is a function with argument `offest(a::Agent)`.
It targets scenarios where multiple agents existin within
a grid cell as it adds an offset (same type as `agent.pos`) to the plotted agent position.

All other keywords are propagated into `Plots.scatter` and the plot is returned.

    plotabm(model::ABM{<: GraphSpace}; ac, as, am, kwargs...)
This function is the same as `plotabm` for `ContinuousSpace`, but here the three key
functions `ac, as, am` do not get an agent as an input but a vector of agents at
each node of the graph. Their output is the same.

Here `as` defaults to `length`. Internally, the `graphplot` recipe is used, and
all other `kwargs...` are propagated there.
"""
plotabm(args...; kw...) = RecipesBase.plot(PlotABM{typeof(args[1].space)}(args); kw...)

"""
    plotabm!(model)
    plotabm!(plt, model)

Functionally the same as [`plotabm`](@ref), however this method appends to the active
plot, or one identified as `plt`.
"""
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
    if scheduler === nothing
        scheduler = model.scheduler
    end

    ids = scheduler(model)
    colors = typeof(ac) <: Function ? [ac(model[i]) for i in ids] : ac
    sizes = typeof(as) <: Function ? [as(model[i]) for i in ids] : as
    markers = typeof(am) <: Function ? [am(model[i]) for i in ids] : am

    if offset === nothing
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

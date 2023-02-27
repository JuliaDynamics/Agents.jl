# Some deprecations exist in submodules Pathfinding, OSM

@deprecate edistance euclidean_distance
@deprecate rem_node! rem_vertex!
@deprecate add_node! add_vertex!

function ContinuousSpace(extent, spacing; kwargs...)
    @warn "Specifying `spacing` by position is deprecated. Use keyword `spacing` instead."
    return ContinuousSpace(extent; spacing = spacing, kwargs...)
end

"""
    seed!(model [, seed])

Reseed the random number pool of the model with the given seed or a random one,
when using a pseudo-random number generator like `MersenneTwister`.
"""
function seed!(model::ABM, args...)
    @warn "`seed!(model::ABM, ...)` is deprecated. Do `seed!(abmrng(model), ...)`."
    Random.seed!(abmrng(model), args...)
end

# From before the move to an interface for ABMs and making `ABM` abstract.
AgentBasedModel(args...; kwargs...) = SingleContainerABM(args...; kwargs...)

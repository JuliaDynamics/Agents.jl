# Some deprecations exist in submodules Pathfinding, OSM

@deprecate edistance euclidean_distance

function ContinuousSpace(extent, spacing; kwargs...)
    @warn "Specifying `spacing` by position is deprecated. Use keyword `spacing` instead."
    return ContinuousSpace(extent; spacing = spacing, kwargs...)
end
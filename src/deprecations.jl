function ContinuousSpace(
    extent,
    spacing;
    kwargs...,
)
    @warn "Giving `spacing` as a positional argument to `ContinuousSpace` is "*
    "deprecated, provide it as a keyword instead."
    return ContinuousSpace(extend; spacing, kwargs...)
end


function __init__()
    # Plot recipes
    @require Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80" begin
        include("visualization/plot-recipes.jl")
    end
end

# 4.0 Depreciations
@deprecate space_neighbors nearby_ids
@deprecate node_neighbors nearby_positions
@deprecate get_node_contents ids_in_position
@deprecate get_node_agents agents_in_position
@deprecate pick_empty random_empty
@deprecate find_empty_nodes empty_positions
@deprecate has_empty_nodes has_empty_positions
@deprecate nodes positions

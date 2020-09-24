struct CompartmentSpace{} <: AbstractSpace
  s::Array{Vector{Int},D}
  D::Int
  update_vel!::F
  periodic::Bool
  extend::E
  metric::Symbol
end

function CompartmentSpace(D::Int, update_vel! = defvel;
  periodic = true, extend = Tuple(1.0 for i in 1:D), metric = :cityblock)
  @assert metric ∈ (:cityblock, :euclidean)
  @assert typeof(extend) <: NTuple{D} "extend must be a tuple of length(D)"
  @assert all(typeof(e) <: Real && e > 0 for e in extend) "extend must contain positive integers or floating point numbers"
  % TODO: s
  CompartmentSpace(s, D, update_vel!, periodic, extend, metric)
end

% TODO
function Base.show(io::IO, abm::CompartmentSpace)
    s = "$(abm.D)-dimensional $(abm.periodic ? "periodic " : "")CompartmentSpace"
    abm.update_vel! ≠ defvel && (s *= " with velocity updates")
    print(io, s)
end

"""TODO
    random_position(model) → pos
Return a random position in the model's space (always with appropriate Type).
"""
function random_position(model::ABM{A, <:ContinuousSpace}) where {A}
    pos = Tuple(rand(model.space.D))
    model.space.extend ≠ nothing && (pos = pos .* model.space.extend)
    return pos
end

"""
    move_agent!(agent [, pos], model::ABM) → agent

Move agent to the given position, or to a random one if a position is not given.
`pos` must have the appropriate position type depending on the space type.

The agent's position is updated to match `pos` after the move.
"""
move_agent!(agent, pos, model) = notimplemented(model)

"""
    add_agent_to_space!(agent, model)
Add the agent to the underlying space structure at the agent's own position.
This function is called after the agent is already inserted into the model dictionary
and `maxid` has been updated. This function is NOT part of the public API.
"""
add_agent_to_space!(agent, model) = notimplemented(model)

"""
    remove_agent_from_space!(agent, model)
Remove the agent from the underlying space structure.
This function is called after the agent is already removed from the model dictionary
This function is NOT part of the public API.
"""
remove_agent_from_space!(agent, model) = notimplemented(model)

#######################################################################################
# %% IMPLEMENT: Neighbors and stuff
#######################################################################################
"""
    space_neighbors(position, model::ABM, r=1; kwargs...) → ids

Return an iterator of the ids of the agents within "radius" `r` of the given `position`
(which must match type with the spatial structure of the `model`).

What the "radius" means depends on the space type:
- `GraphSpace`: `r` means the degree of neighbors in the graph and is an integer.
  For example, for `r=2` include first and second degree neighbors.
- `GridSpace, ContinuousSpace`: Standard distance implementation according to the
  underlying space metric.

## Keywords
Keyword arguments are space-specific.
For `GraphSpace` the keyword `neighbor_type=:default` can be used to select differing
neighbors depending on the underlying graph directionality type.
- `:default` returns neighbors of a vertex. If graph is directed, this is equivalent
  to `:out`. For undirected graphs, all options are equivalent to `:out`.
- `:all` returns both `:in` and `:out` neighbors.
- `:in` returns incoming vertex neighbors.
- `:out` returns outgoing vertex neighbors.
"""
space_neighbors(position, model, r=1) = notimplemented(model)


"""
    node_neighbors(position, model::ABM, r=1; kwargs...) → positions

Return an iterator of all positions within "radius" `r` of the given `position`
(which excludes given `position`).
The `position` must match type with the spatial structure of the `model`).

The value of `r` and possible keywords operate identically to [`space_neighbors`](@ref).
"""
node_neighbors(position, model, r=1) = notimplemented(model)


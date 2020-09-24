export CompartmentSpace

struct CompartmentSpace{D,F} <: AbstractSpace
  s::Array{Vector{Int},D}
  update_vel!::F
  periodic::Bool
  metric::Symbol
  dims::NTuple{D, Int}
  extent::NTuple{D, Float64}
  D::Int
end

defvel(a, m) = nothing

function CompartmentSpace(d::NTuple{D,Real}, spacing;
  update_vel! = defvel, periodic = true, metric = :cityblock) where {D}
  
  @assert metric ∈ (:cityblock, :euclidean)
  s = Array{Vector{Int},D}(undef, round.(Int, d ./ spacing))
  for i in eachindex(s)
    s[i] = Int[]
  end
  return CompartmentSpace{D,typeof(update_vel!)}(s, update_vel!, periodic, metric, size(s), d, D)
end

function Base.show(io::IO, space::CompartmentSpace)
  s = "$(space.periodic ? "periodic" : "") continuous space on with $(join(space.dims, "×")) divisions"
  space.update_vel! ≠ defvel && (s *= " with velocity updates")
  print(io, s)
end

"""
    random_position(model) → pos
Return a random position in the model's space (always with appropriate Type).
"""
function random_position(model::ABM{A, <:CompartmentSpace}) where {A}
  pos = Tuple(rand(model.space.D))
end

pos_to_cell(pos::Tuple, model) = ceil.(Int, pos .* model.space.dims)
pos_to_cell(a::A, model) where {A<:AbstractAgent} = pos_to_cell(a.pos, model)

function add_agent_to_space!(a::A, model::ABM{A,<:CompartmentSpace}) where {A<:AbstractAgent}
    push!(model.space.s[pos_to_cell(a, model)...], a.id)
    return a
end

function remove_agent_from_space!(a::A, model::ABM{A,<:CompartmentSpace}) where {A<:AbstractAgent}
    prev = model.space.s[pos_to_cell(a, model)...]
    ai = findfirst(i -> i == a.id, prev)
    deleteat!(prev, ai)
    return a
end

function move_agent!(a::A, pos::Tuple, model::ABM{A,<:CompartmentSpace}) where {A<:AbstractAgent}
  remove_agent_from_space!(a, model)
  a.pos = pos
  add_agent_to_space!(a, model)
end

"""
    move_agent!(agent::A, model::ABM{A, CompartmentSpace}, dt = 1.0)
Propagate the agent forwards one step according to its velocity,
_after_ updating the agent's velocity (see [`CompartmentSpace`](@ref)).
Also take care of periodic boundary conditions.

For this continuous space version of `move_agent!`, the "evolution algorithm"
is a trivial Euler scheme with `dt` the step size, i.e. the agent position is updated
as `agent.pos += agent.vel * dt`.

Notice that if you want the agent to instantly move to a specified position, do
`move_agent!(agent, pos, model)`.
"""
function move_agent!(agent::A, model::ABM{A, <: CompartmentSpace}, dt::Real = 1.0) where {A <: AbstractAgent}
  model.space.update_vel!(agent, model)
  pos = agent.pos .+ dt .* agent.vel
  if model.space.periodic
    pos = mod.(pos, model.space.extent)
  end
  move_agent!(agent, pos, model)
  return agent.pos
end

"""
    move_agent!(agent::A, model::ABM{A, CompartmentSpace}, vel::NTuple{D, N}, dt = 1.0)
Propagate the agent forwards one step according to `vel` and the model's space, with `dt` as the time step. (`update_vel!` is not used)
"""
function move_agent!(agent::A, model::ABM{A,S,F,P}, vel::NTuple{D, X}, dt = 1.0) where {A <: AbstractAgent, S <: CompartmentSpace, F, P, D, X <: AbstractFloat}
  pos = agent.pos .+ dt .* vel
  if model.space.periodic
    pos = mod.(pos, model.space.extent)
  end
  move_agent!(agent, pos, model)
  return agent.pos
end

#######################################################################################
# %% IMPLEMENT: Neighbors and stuff
#######################################################################################

function cell_center(cell::Tuple, model)
  divisions = 1.0 ./ model.space.dims
  cell_max = cell .* divisions
  center = cell_max .- (divisions ./2)
  return center
end

function distance_from_cell_center(pos::Tuple, model)
  cell = pos_to_cell(pos, model)
  δ = sqrt(sum(abs2.(pos .- cell_center(cell, model))))
  return δ
end

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
space_neighbors(position, model, r=1; exact=false) = notimplemented(model)


"""
    node_neighbors(position, model::ABM, r=1; kwargs...) → positions

Return an iterator of all positions within "radius" `r` of the given `position`
(which excludes given `position`).
The `position` must match type with the spatial structure of the `model`).

The value of `r` and possible keywords operate identically to [`space_neighbors`](@ref).
"""
node_neighbors(position, model, r=1; exact=false) = notimplemented(model)


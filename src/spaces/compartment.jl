export CompartmentSpace

struct CompartmentSpace{D,F} <: AbstractSpace
  grid::GridSpace
  update_vel!::F
  dims::NTuple{D, Int}
  periodic::Bool
  D::Int
  spacing::Float64
end

defvel(a, m) = nothing

function CompartmentSpace(d::NTuple{D,Real}, spacing;
  update_vel! = defvel, periodic = true, metric = :cityblock) where {D}
  s = GridSpace(floor.(Int, d ./ spacing), periodic=periodic, metric=metric)
  return CompartmentSpace{D,typeof(update_vel!)}(s, 
    update_vel!, size(s),periodic, D, spacing)
end

"""
    random_position(model) → pos
Return a random position in the model's space (always with appropriate Type).
"""
function random_position(model::ABM{A, <:CompartmentSpace}) where {A}
  pos = Tuple(rand(model.space.D) .* model.space.dims)
end

pos2cell(pos::Tuple) = ceil.(Int, pos)
pos2cell(a::AbstractAgent) = pos2cell(a.pos)

function add_agent_to_space!(a::A, model::ABM{A,<:CompartmentSpace}) where 
  {A<:AbstractAgent}
  push!(model.space.grid.s[pos2cell(a)...], a.id)
  return a
end

function remove_agent_from_space!(a::A, model::ABM{A,<:CompartmentSpace}) where 
  {A<:AbstractAgent}
  prev = model.space.grid.s[pos2cell(a)...]
  ai = findfirst(i -> i == a.id, prev)
  deleteat!(prev, ai)
  return a
end

function move_agent!(a::A, pos::Tuple, model::ABM{A,<:CompartmentSpace}) where 
  {A<:AbstractAgent}
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
    pos = mod.(pos, model.space.dims)
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
    pos = mod.(pos, model.space.dims)
  end
  move_agent!(agent, pos, model)
  return agent.pos
end

#######################################################################################
# %% Neighbors and stuff
#######################################################################################

grid_space_neighborhood(α, model::ABM{<:AbstractAgent, <:CompartmentSpace}, r) =
  grid_space_neighborhood(α, model.space.grid, r)

function nearby_ids(pos::ValidPos, model::ABM{<:AbstractAgent,<:CompartmentSpace}, r = 1)
    nn = grid_space_neighborhood(CartesianIndex(pos), model, r)
    s = model.space.grid.s
    Iterators.flatten((s[i...] for i in nn))
end

function nearby_positions(pos::ValidPos, model::ABM{<:AbstractAgent,<:CompartmentSpace}, r = 1)
    nn = grid_space_neighborhood(CartesianIndex(pos), model, r)
    Iterators.filter(!isequal(pos), nn)
end

function positions(model::ABM{<:AbstractAgent,<:CompartmentSpace})
  x = CartesianIndices(model.space.grid.s)
  return (Tuple(y) for y in x)
end

function ids_in_position(pos::ValidPos, model::ABM{<:AbstractAgent,<:CompartmentSpace})
    return model.space.grid.s[pos...]
end

cell_center(pos::Tuple) = getindex.(modf.(pos), 2) .+ 0.5
distance_from_cell_center(pos::Tuple) = sqrt(sum(abs2.(pos .- cell_center(pos))))

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
function space_neighbors(pos, model, r=1; exact=false)
  if exact
    cell_in_r = ceil.(Int, r ./ model.space.spacing)
  else
    δ = distance_from_cell_center(pos)
    cell_in_rp = ceil.(Int, (r+δ) ./ model.space.spacing)
    # for cell in nearby_positions(pos, model::ABM{<:AbstractAgent,<:GridSpace}, r = 1)
  end
end


"""
    node_neighbors(position, model::ABM, r=1; kwargs...) → positions

Return an iterator of all positions within "radius" `r` of the given `position`
(which excludes given `position`).
The `position` must match type with the spatial structure of the `model`).

The value of `r` and possible keywords operate identically to [`space_neighbors`](@ref).
"""
node_neighbors(position, model, r=1; exact=false) = notimplemented(model)


################################################################################
### Pretty printing
################################################################################

function Base.show(io::IO, space::CompartmentSpace)
  s = "$(space.periodic ? "periodic" : "") continuous space with $(join(space.dims, "×")) divisions"
  space.update_vel! ≠ defvel && (s *= " with velocity updates")
  print(io, s)
end

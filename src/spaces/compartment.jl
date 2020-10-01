export CompartmentSpace

struct CompartmentSpace{D,P,F} <: AbstractSpace
    grid::GridSpace{D,P}
    update_vel!::F
    dims::NTuple{D, Int}
    spacing::Float64
    extent::NTuple{D, Float64}
end

defvel2(a, m) = nothing

"""
    CompartmentSpace(extent::NTuple{D,Real}, spacing; kwargs...)
Create a `CompartmentSpace` in range 0 to extent and with `spacing` divisions.
For maximum performance, choose `spacing` such that there is approximately
one agent per cell.
In this case, your agent positions (field `pos`) should be of type `NTuple{D, F}`
where `F <: AbstractFloat`.
In addition, the agent type should have a third field `vel::NTuple{D, F}` representing
the agent's velocity to use [`move_agent!`](@ref).

The optional argument `update_vel!` is a **function**, `update_vel!(agent, model)` that updates
the agent's velocity **before** the agent has been moved, see [`move_agent!`](@ref).
You can of course change the agents' velocities
during the agent interaction, the `update_vel!` functionality targets arbitrary force
fields acting on the agents (e.g. some magnetic field).
By default no update is done this way.

Notice that if you need to write your own custom `move_agent` function, call
[`update_space!`](@ref) at the end, like in e.g. the [Bacterial Growth](@ref) example.

## Keywords
* `periodic = true` : whether continuous space is periodic or not
* `update_vel! = defvel2` : see above.

**Note:** if your model requires linear algebra operations for which tuples are not supported,
a performant solution is to convert between Tuple and SVector using
[StaticArrays.jl](https://github.com/JuliaArrays/StaticArrays.jl)
as follows: `s = SVector(t)` and back with `t = Tuple(s)`.
"""
function CompartmentSpace(extent::NTuple{D,Real}, spacing;
    update_vel! = defvel2, periodic = true) where {D}
    s = GridSpace(ceil.(Int, extent ./ spacing), periodic=periodic, metric=:euclidean)
    return CompartmentSpace(s, update_vel!, size(s), spacing, Float64.(extent))
end

function random_position(model::ABM{A, <:CompartmentSpace{D}}) where {A,D}
    pos = Tuple(rand(D) .* model.space.extent)
end

pos2cell(pos::Tuple, model) = ceil.(Int, pos ./ model.space.spacing)
pos2cell(a::AbstractAgent, model) = pos2cell(a.pos, model)

function add_agent_to_space!(a::A, model::ABM{A,<:CompartmentSpace}) where
    {A<:AbstractAgent}
    push!(model.space.grid.s[pos2cell(a, model)...], a.id)
    return a
end

function remove_agent_from_space!(a::A, model::ABM{A,<:CompartmentSpace}) where
    {A<:AbstractAgent}
    prev = model.space.grid.s[pos2cell(a, model)...]
    ai = findfirst(i -> i == a.id, prev)
    deleteat!(prev, ai)
    return a
end

function move_agent!(a::A, pos::Tuple, model::ABM{A,<:CompartmentSpace{D,periodic}}) where {A<:AbstractAgent, D, periodic}
    remove_agent_from_space!(a, model)
    if periodic
        pos = mod.(pos, model.space.extent)
    end
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
    move_agent!(agent, pos, model)
    return agent.pos
end

#######################################################################################
# %% Neighbors and stuff
#######################################################################################

grid_space_neighborhood(α, model::ABM{<:AbstractAgent, <:CompartmentSpace}, r) =
grid_space_neighborhood(α, model.space.grid, r)

function nearby_ids_cell(pos::ValidPos, model::ABM{<:AbstractAgent,<:CompartmentSpace}, r = 1)
    nn = grid_space_neighborhood(CartesianIndex(pos2cell(pos, model)), model, r)
    s = model.space.grid.s
    Iterators.flatten((s[i...] for i in nn))
end

function nearby_positions(pos::ValidPos, model::ABM{<:AbstractAgent,<:CompartmentSpace}, r = 1)
    nn = grid_space_neighborhood(CartesianIndex(pos2cell(pos, model)), model, r)
    Iterators.filter(!isequal(pos), nn)
end

function positions(model::ABM{<:AbstractAgent,<:CompartmentSpace})
    x = CartesianIndices(model.space.grid.s)
    return (Tuple(y) for y in x)
end

function ids_in_position(pos::ValidPos, model::ABM{<:AbstractAgent,<:CompartmentSpace})
    return model.space.grid.s[pos...]
end

cell_center(pos, model) = ((pos2cell(pos, model) .- 1) .* model.space.spacing) .+ model.space.spacing/2
distance_from_cell_center(pos::Tuple, center) = sqrt(sum(abs2.(pos .- center)))

"""
        nearby_ids(pos::ValidPos, model::ABM{<:AbstractAgent,<:CompartmentSpace}, r=1; exact=false) → ids

Return an iterable of the ids of the agents within "radius" `r` of the given `position` in `CompartmentSpace`.

If an agent is given instead of a position `pos`, the id of the agent is excluded.

# Keywords
* `exact=false` checks for exact distance rather than returing the ids of all
agents in a circle within `r` when true. If false, returns all the cells in a square with
side equals 2(ceil(r)) and the pos at its center. `exact=false` is faster.
"""
function nearby_ids(pos::ValidPos, model::ABM{<:AbstractAgent,<:CompartmentSpace{D}}, r=1; exact=false) where {D}
    if exact
        grid_r_max = r < model.space.spacing ? r : ceil.(Int, r ./ model.space.spacing)
        focal_cell = pos2cell(pos, model)
        sqrtD = sqrt(D)
        allcells = grid_space_neighborhood(CartesianIndex(focal_cell), model, grid_r_max + sqrtD)
        if grid_r_max >= 1
            certain_cells = grid_space_neighborhood(CartesianIndex(focal_cell), model, grid_r_max - sqrtD)
            certain_ids = Iterators.flatten(ids_in_position(cell, model) for cell in certain_cells)

            uncertain_cells = setdiff(allcells, certain_cells) # This allocates, but not sure if there's a better way.
            uncertain_ids = Iterators.flatten(ids_in_position(cell, model) for cell in uncertain_cells)

            additional_ids = Iterators.filter(i->sqrt(sum(abs2.(pos .- model[i].pos))) ≤ r, uncertain_ids)

            return Iterators.flatten((certain_ids, additional_ids))
        else
            all_ids = Iterators.flatten(ids_in_position(cell, model) for cell in allcells)
            return Iterators.filter(i->sqrt(sum(abs2.(pos .- model[i].pos))) ≤ r, all_ids)
        end
    else
        δ = distance_from_cell_center(pos, cell_center(pos, model))
        grid_r = r+δ > model.space.spacing ?  ceil(Int, (r+δ)  / model.space.spacing) : 1
        return nearby_ids_cell(pos, model, grid_r)
    end
end

function nearby_ids(a::A, model::ABM{A, <:CompartmentSpace}, r=1; exact=false) where {A<:AbstractAgent}
    ids = nearby_ids(a.pos, model, r, exact=exact)
    Iterators.filter(x -> x != a.id, ids)
end
################################################################################
### Pretty printing
################################################################################
function Base.show(io::IO, space::CompartmentSpace{D,P}) where {D, P}
    s = "$(P ? "periodic" : "") continuous space with $(join(space.dims, "×")) divisions"
    space.update_vel! ≠ defvel && (s *= " with velocity updates")
    print(io, s)
end


#######################################################################################
# Continuous space exclusive
#######################################################################################
export nearest_neighbor, elastic_collision!, interacting_pairs

"""
    nearest_neighbor(agent, model, r) → nearest
Return the agent that has the closest distance to given `agent`. Valid only in continuous space.
Return `nothing` if no agent is within distance `r`.
"""
function nearest_neighbor(agent::A, model::ABM{A, <:CompartmentSpace}, r; exact=false) where {A}
  n = collect(nearby_ids(agent, model, r; exact=exact))
  length(n) == 0 && return nothing
  d, j = Inf, 1
  for i in 1:length(n)
    @inbounds dnew = sqrt(sum(abs2.(agent.pos .- model[n[i]].pos)))
    if dnew < d
      d, j = dnew, i
    end
  end
  return @inbounds model[n[j]]
end

using LinearAlgebra

"""
    elastic_collision!(a, b, f = nothing)
Resolve a (hypothetical) elastic collision between the two agents `a, b`.
They are assumed to be disks of equal size touching tangentially.
Their velocities (field `vel`) are adjusted for an elastic collision happening between them.
This function works only for two dimensions.
Notice that collision only happens if both disks face each other, to avoid
collision-after-collision.

If `f` is a `Symbol`, then the agent property `f`, e.g. `:mass`, is taken as a mass
to weight the two agents for the collision. By default no weighting happens.

One of the two agents can have infinite "mass", and then acts as an immovable object
that specularly reflects the other agent. In this case of course momentum is not
conserved, but kinetic energy is still conserved.
"""
function elastic_collision!(a, b, f = nothing)
  # Do elastic collision according to
  # https://en.wikipedia.org/wiki/Elastic_collision#Two-dimensional_collision_with_two_moving_objects
  v1, v2, x1, x2 = a.vel, b.vel, a.pos, b.pos
  length(v1) != 2 && error("This function works only for two dimensions.")
  r1 = x1 .- x2; r2 = x2 .- x1
  m1, m2 = f == nothing ? (1.0, 1.0) : (getfield(a, f), getfield(b, f))
  # mass weights
  m1 == m2 == Inf && return false
  if m1 == Inf
    @assert v1 == (0, 0) "An agent with ∞ mass cannot have nonzero velocity"
    dot(r1, v2) ≤ 0 && return false
    v1 = ntuple(x -> zero(eltype(v1)), length(v1))
    f1, f2 = 0.0, 2.0
  elseif m2 == Inf
    @assert v2 == (0, 0) "An agent with ∞ mass cannot have nonzero velocity"
    dot(r2, v1) ≤ 0 && return false
    v2 = ntuple(x -> zero(eltype(v1)), length(v1))
    f1, f2 = 2.0, 0.0
  else
    # Check if disks face each other, to avoid double collisions
    !(dot(r2, v1) > 0 && dot(r2, v1) > 0) && return false
    f1 = (2m2/(m1+m2))
    f2 = (2m1/(m1+m2))
  end
  ken = norm(v1)^2 + norm(v2)^2
  dx = a.pos .- b.pos
  dv = a.vel .- b.vel
  n = norm(dx)^2
  n == 0 && return false # do nothing if they are at the same position
  a.vel = v1 .- f1 .* ( dot(v1 .- v2, r1) / n ) .* (r1)
  b.vel = v2 .- f2 .* ( dot(v2 .- v1, r2) / n ) .* (r2)
  return true
end

"""
    interacting_pairs(model, r, method; scheduler = model.scheduler)
Return an iterator that yields unique pairs of agents `(a1, a2)` that are close
neighbors to each other, within some interaction radius `r`.

This function is usefully combined with `model_step!`, when one wants to perform
some pairwise interaction across all pairs of close agents once
(and does not want to trigger the event twice, both with `a1` and with `a2`, which
is unavoidable when using `agent_step!`).

The argument `method` provides three pairing scenarios
- `:all`: return every pair of agents that are within radius `r` of each other,
  not only the nearest ones.
- `:nearest`: agents are only paired with their true nearest neighbor
  (existing within radius `r`).
  Each agent can only belong to one pair, therefore if two agents share the same nearest
  neighbor only one of them (sorted by id) will be paired.
- `:scheduler`: agents are scanned according to the given keyword `scheduler`
  (by default the model's scheduler), and each scanned
  agent is paired to its nearest neighbor. Similar to `:nearest`, each agent can belong
  to only one pair. This functionality is useful e.g. when you want some agents to be
  paired "guaranteed", even if some other agents might be nearest to each other.
- `:types`: For mixed agent models only. Return every pair of agents within radius `r`
  (similar to `:all`), only capturing pairs of differing types. For example, a model of
  `Union{Sheep,Wolf}` will only return pairs of `(Sheep, Wolf)`. In the case of multiple
  agent types, *e.g.* `Union{Sheep, Wolf, Grass}`, skipping pairings that involve
  `Grass`, can be achived by a [`scheduler`](@ref Schedulers) that doesn't schedule `Grass`
  types, *i.e.*: `scheduler = [a.id for a in allagents(model) of !(a isa Grass)]`.
"""
function interacting_pairs(model::ABM{A, <:CompartmentSpace}, r::Real, method; scheduler = model.scheduler, exact=true) where {A}
    @assert method ∈ (:scheduler, :nearest, :all, :types)
    pairs = Tuple{Int,Int}[]
    if method == :nearest
        true_pairs!(pairs, model, r)
    elseif method == :scheduler
        scheduler_pairs!(pairs, model, r, scheduler)
    elseif method == :all
        all_pairs!(pairs, model, r, exact=exact)
    elseif method == :types
        type_pairs!(pairs, model, r, scheduler, exact=exact)
    end
    return PairIterator(pairs, model.agents)
end

function scheduler_pairs!(pairs::Vector{Tuple{Int,Int}}, model::ABM{A, <:CompartmentSpace}, r::Real, scheduler) where {A}
    #TODO: This can be optimized further I assume
    for id in scheduler(model)
        # Skip already checked agents
        any(isequal(id), p[2] for p in pairs) && continue
        a1 = model[id]
        a2 = nearest_neighbor(a1, model, r)
        # This line ensures each neighbor exists in only one pair:
        if a2 ≠ nothing && !any(isequal(a2.id), p[2] for p in pairs)
            push!(pairs, (id, a2.id))
        end
    end
end

function all_pairs!(pairs::Vector{Tuple{Int,Int}}, model::ABM{A, <:CompartmentSpace}, r::Real; exact=true) where {A}
    for a in allagents(model)
        for nid in nearby_ids(a, model, r; exact=exact)
            # Sort the pair to overcome any uniqueness issues
            new_pair = isless(a.id, nid) ? (a.id, nid) : (nid, a.id)
            new_pair ∉ pairs && push!(pairs, new_pair)
        end
    end
end

function true_pairs!(pairs::Vector{Tuple{Int,Int}}, model::ABM{A, <:CompartmentSpace}, r::Real) where {A}
    distances = Vector{Float64}(undef, 0)
    for a in allagents(model)
        nn = nearest_neighbor(a, model, r)
        nn == nothing && continue
        # Sort the pair to overcome any uniqueness issues
        new_pair = isless(a.id, nn.id) ? (a.id, nn.id) : (nn.id, a.id)
        if new_pair ∉ pairs
            # We also need to check if our current pair is closer to each
            # other than any pair using our first id already in the list,
            # so we keep track of nn distances.
            dist = pair_distance(a.pos, model[nn.id].pos)

            idx = findfirst(x -> first(new_pair) == x, first.(pairs))
            if idx == nothing
                push!(pairs, new_pair)
                push!(distances, dist)
            elseif idx != nothing && distances[idx] > dist
                # Replace this pair, it is not the true neighbor
                pairs[idx] = new_pair
                distances[idx] = dist
            end
        end
    end
end

function type_pairs!(pairs::Vector{Tuple{Int,Int}}, model::ABM{A, <:CompartmentSpace}, r::Real, scheduler; exact=true) where {A}
    # We don't know ahead of time what types the scheduler will provide. Get a list.
    available_types = unique(typeof(model[id]) for id in scheduler(model))
    for id in scheduler(model)
        for nid in nearby_ids(model[id], model, r, exact=exact)
            neigbor_type = typeof(model[nid])
            if neigbor_type ∈ available_types && neigbor_type !== typeof(model[id])
                # Sort the pair to overcome any uniqueness issues
                new_pair = isless(id, nid) ? (id, nid) : (nid, id)
                new_pair ∉ pairs && push!(pairs, new_pair)
            end
        end
    end
end

function pair_distance(pos1, pos2)
    sqrt(sum(abs2.(pos1 .- pos2)))
end

struct PairIterator{A}
    pairs::Vector{Tuple{Int,Int}}
    agents::Dict{Int,A}
end

Base.length(iter::PairIterator) = length(iter.pairs)
function Base.iterate(iter::PairIterator, i = 1)
    i > length(iter) && return nothing
    p = iter.pairs[i]
    id1, id2 = p
    return (iter.agents[id1], iter.agents[id2]), i + 1
end

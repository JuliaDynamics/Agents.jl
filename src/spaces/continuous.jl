export ContinuousSpace, ContinuousAgent
export nearby_ids_exact, nearby_agents_exact
export nearest_neighbor, elastic_collision!, interacting_pairs

struct ContinuousSpace{D,P,T<:AbstractFloat,F} <: AbstractSpace
    grid::GridSpace{D,P}
    update_vel!::F
    dims::NTuple{D,Int}
    spacing::T
    extent::NTuple{D,T}
end
Base.eltype(s::ContinuousSpace{D,P,T,F}) where {D,P,T,F} = T
no_vel_update(a, m) = nothing
spacesize(space::ContinuousSpace) = space.extent
function Base.show(io::IO, space::ContinuousSpace{D,P}) where {D,P}
    s = "$(P ? "periodic" : "") continuous space with $(spacesize(space)) extent"*
    " and spacing=$(space.spacing)"
    space.update_vel! ≠ no_vel_update && (s *= " with velocity updates")
    print(io, s)
end

@agent ContinuousAgent{D} NoSpaceAgent begin
    pos::NTuple{D,Float64}
    vel::NTuple{D,Float64}
end

@doc """
    ContinuousAgent{D} <: AbstractAgent
The minimal agent struct for usage with `D`-dimensional [`ContinuousSpace`](@ref).
It has the additoinal fields `pos::NTuple{D,Float64}, vel::NTuple{D,Float64}`.
See also [`@agent`](@ref).
""" ContinuousAgent

"""
    ContinuousSpace(extent::NTuple{D, <:Real}; kwargs...)
Create a `D`-dimensional `ContinuousSpace` in range 0 to (but not including) `extent`.
Your agent positions (field `pos`) must be of type `NTuple{D, <:Real}`,
and it is strongly recommend that agents also have a field `vel::NTuple{D, <:Real}` to use
in conjunction with [`move_agent!`](@ref). Use [`ContinuousAgent`](@ref) for convenience.

`ContinuousSpace` is a representation of agent dynamics on a continuous medium
where agent position, orientation, and speed, are true floats.
In addition, support is provided for representing spatial properties in a model
that contains a `ContinuousSpace`. Spatial properties (which typically are contained in
the model properties) can either be functions of the position vector, `f(pos) = value`,
or `AbstractArrays`, representing discretizations of
spatial data that may not be available in analytic form. In the latter case,
the position is automatically mapped into the discretization represented by the array.
Use [`get_spatial_property`](@ref) to access spatial properties in conjuction with
`ContinuousSpace`.

See also [Continuous space exclusives](@ref) on the online docs for more functionality.
An example using continuous space is the [Flocking model](@ref).

## Distance specification
Distances specified by `r` in functions like [`nearby_ids`](@ref) are always based
on the Euclidean distance between two points in `ContinuousSpace`.

In `ContinuousSpace` `nearby_*` searches are accelerated using a grid system, see
discussion around the keyword `spacing` below. [`nearby_ids`](@ref) is not an exact
search, but can be a possible over-estimation, including agent IDs whose distance
slightly exceeds `r` with "slightly" being as much as `spacing`.
If you want exact searches use the slower [`nearby_ids_exact`](@ref).

## Keywords
* `periodic = true`: Whether the space is periodic or not. If set to
  `false` an error will occur if an agent's position exceeds the boundary.
* `spacing::Real = minimum(extent)/20`: Configures an internal compartment spacing that
  is used to accelerate nearest neighbor searches like [`nearby_ids`](@ref).
  The compartments are actually a full instance of `GridSpace` in which agents move.
  All dimensions in `extent` must be completely divisible by `spacing`.
  There is no best choice for the value of `spacing` and if you need optimal performance
  it's advised to set up a benchmark over a range of choices. The finer the spacing,
  the faster and more accurate the inexact version of `nearby_ids` becomes. However,
  a finer spacing also means slower `move_agent!`, as agents change compartments more often.
* `update_vel!`: A **function**, `update_vel!(agent, model)` that updates
  the agent's velocity **before** the agent has been moved, see [`move_agent!`](@ref).
  You can of course change the agents' velocities
  during the agent interaction, the `update_vel!` functionality targets spatial force
  fields acting on the agents individually (e.g. some magnetic field).
  If you use `update_vel!`, the agent type must have a field `vel::NTuple{D, <:Real}`.
"""
function ContinuousSpace(
    extent::NTuple{D,X};
    spacing = minimum(extent)/20.0,
    update_vel! = no_vel_update,
    periodic = true,
) where {D,X<:Real}
    if extent ./ spacing != floor.(extent ./ spacing)
        error("All dimensions in `extent` must be completely divisible by `spacing`")
    end
    s = GridSpace(floor.(Int, extent ./ spacing); periodic, metric = :euclidean)
    Z = X <: AbstractFloat ? X : Float64
    return ContinuousSpace(s, update_vel!, size(s), Z(spacing), Z.(extent))
end

function random_position(model::ABM{<:ContinuousSpace})
    map(dim -> rand(model.rng) * dim, spacesize(model))
end

"given position in continuous space, return cell coordinates in grid space."
pos2cell(pos::Tuple, model::ABM) = @. floor(Int, pos/model.space.spacing) + 1
pos2cell(a::AbstractAgent, model::ABM) = pos2cell(a.pos, model)

"given position in continuous space, return continuous space coordinates of cell center."
function cell_center(pos::NTuple{D,<:AbstractFloat}, model) where {D}
    ε = model.space.spacing
    (pos2cell(pos, model) .- 1) .* ε .+ ε/2
end

distance_from_cell_center(pos, model::ABM) =
    distance_from_cell_center(pos, cell_center(pos, model))
function distance_from_cell_center(pos::Tuple, center::Tuple)
    sqrt(sum(abs2.(pos .- center)))
end

function add_agent_to_space!(
    a::A, model::ABM{<:ContinuousSpace,A}, cell_index = pos2cell(a, model)) where {A<:AbstractAgent}
    push!(model.space.grid.stored_ids[cell_index...], a.id)
    return a
end

function remove_agent_from_space!(
    a::A,
    model::ABM{<:ContinuousSpace,A},
    cell_index = pos2cell(a, model),
) where {A<:AbstractAgent}
    prev = model.space.grid.stored_ids[cell_index...]
    ai = findfirst(i -> i == a.id, prev)
    deleteat!(prev, ai)
    return a
end

# We re-write this for performance, because if cell doesn't change, we don't have to
# move the agent in the GridSpace; only change its position field
function move_agent!(agent::A, pos::ValidPos, model::ABM{<:ContinuousSpace{D},A}
    ) where {D, A<:AbstractAgent}
    for i in 1:D
        pos[i] > spacesize(model)[i] && error("position is outside space extent!")
    end
    oldcell = pos2cell(agent, model)
    newcell = pos2cell(pos, model)
    if oldcell ≠ newcell
        remove_agent_from_space!(agent, model, oldcell)
        add_agent_to_space!(agent, model, newcell)
    end
    agent.pos = pos
    return agent
end



"""
    move_agent!(agent::A, model::ABM{<:ContinuousSpace,A}, dt::Real)
Propagate the agent forwards one step according to its velocity, _after_ updating the
agent's velocity (if configured using `update_vel!`, see [`ContinuousSpace`](@ref)).

For this continuous space version of `move_agent!`, the "time evolution"
is a trivial Euler scheme with `dt` the step size, i.e. the agent position is updated
as `agent.pos += agent.vel * dt`.

Unlike `move_agent!(agent, [pos,] model)`, this function respects the space size.
For non-periodic spaces, agents will walk up to, but not reach, the space extent.
For periodic spaces movement properly wraps around the extent.
"""
function move_agent!(
    agent::A,
    model::ABM{<:ContinuousSpace,A},
    dt::Real,
) where {A<:AbstractAgent}
    model.space.update_vel!(agent, model)
    direction = dt .* agent.vel
    walk!(agent, direction, model)
end

#######################################################################################
# %% nearby_stuff
#######################################################################################
# TODO: `nearby_stuff` allocate a bit because of the filtering.
# We can make dedicated iterator structures, like with `GridSpace`, and completely
# remove allocations!

# Searching neighbors happens in two passes. First, we search neighbors in the
# internal `GridSpace`, and then we refine them if need be. To understand how this works,
# see https://github.com/JuliaDynamics/Agents.jl/issues/313

# Extend the gridspace function
function offsets_within_radius(model::ABM{<:ContinuousSpace}, r::Real)
    return offsets_within_radius(model.space.grid, r)
end

function nearby_ids(pos::ValidPos, model::ABM{<:ContinuousSpace{D,A,T}}, r = 1;
        exact = false,
    ) where {D,A,T}
    if exact
        @warn("Keyword `exact` in `nearby_ids` is deprecated. Use `nearby_ids_exact`.")
        nearby_ids_exact(pos, model, r)
    end
    # Calculate maximum grid distance (distance + distance from cell center)
    δ = distance_from_cell_center(pos, cell_center(pos, model))
    grid_r = (r + δ) / model.space.spacing
    # Then return the ids within this distance, using the internal grid space
    # and iteration via `GridSpaceIdIterator`, see spaces/grid_multi.jl
    focal_cell = pos2cell(pos, model)
    return nearby_ids(focal_cell, model.space.grid, grid_r)
end

"""
    nearby_ids_exact(x, model, r = 1)
Return an iterator over agent IDs nearby `x` (a position or an agent).
Only valid for `ContinuousSpace` models.
Use instead of [`nearby_ids`](@ref) for a slower, but 100% accurate version.
See [`ContinuousSpace`](@ref) for more details.
"""
function nearby_ids_exact(pos::ValidPos, model::ABM{<:ContinuousSpace{D,A,T}}, r = 1) where {D,A,T}
    # TODO:
    # Simply filtering the output leads to 4x faster code than the commented-out logic.
    # It is because the code of the "fast logic" is actually super type unstable.
    # Hence, we need to re-think how we do this, and probably create dedicated structs
    iter = nearby_ids(pos, model, r)
    return Iterators.filter(i -> euclidean_distance(pos, model[i].pos, model) ≤ r, iter)

    # Remaining code isn't used, but is based on
    #  https://github.com/JuliaDynamics/Agents.jl/issues/313
    #=
    gridspace = model.space.grid
    spacing = model.space.spacing
    focal_cell = pos2cell(pos, model)
    max_dist_from_center = maximum(abs.(pos .- cell_center(pos, model)))
    crosses_at_least_one_cell_border = max_dist_from_center + r ≥ spacing

    if crosses_at_least_one_cell_border # must include more than 1 cell guaranteed
        grid_r_max = r < spacing ? T(1) : r/spacing + T(1)
        allcells = nearby_positions(
            focal_cell, gridspace, grid_r_max, offsets_within_radius
        )
        # TODO: I am not certain if the constant T(1.2)*sqrt(D) is correct
        grid_r_certain = grid_r_max - T(1.2) * sqrt(D)
        certain_cells = nearby_positions(
            focal_cell, gridspace, grid_r_certain, offsets_within_radius)
        certain_ids = nearby_ids(focal_cell, gridspace, grid_r_certain)

        # TODO: This allocates, but not sure if there's a better way...
        uncertain_cells = setdiff(allcells, certain_cells)

        uncertain_ids = Iterators.flatten(
            ids_in_position(cell, gridspace) for cell in uncertain_cells)

        additional_ids = Iterators.filter(
            i -> euclidean_distance(pos, model[i].pos, model) ≤ r,
            uncertain_ids,
        )
        return Iterators.flatten((certain_ids, additional_ids))
    else # only the focal cell is included in this search, so we skip `nearby_ids`
        all_ids = ids_in_position(focal_cell, gridspace)
        # return
        # all_ids = Iterators.flatten(ids_in_position(cell, model) for cell in allcells)
        # all_ids = nearby_ids(focal_cell, gridspace, r)
        return Iterators.filter(i -> euclidean_distance(pos, model[i].pos, model) ≤ r, all_ids)
    end
    =#
end

# Do the standard extensions for `_exact` as in space API
function nearby_ids_exact(agent::A, model::ABM, r = 1) where {A<:AbstractAgent}
    all = nearby_ids_exact(agent.pos, model, r)
    Iterators.filter(i -> i ≠ agent.id, all)
end
nearby_agents_exact(a, model, r=1) = (model[id] for id in nearby_ids_exact(a, model, r))


#######################################################################################
# Continuous space exclusives: collisions, nearest neighbors
#######################################################################################
"""
    nearest_neighbor(agent, model::ABM{<:ContinuousSpace}, r) → nearest
Return the agent that has the closest distance to given `agent`.
Return `nothing` if no agent is within distance `r`.
"""
function nearest_neighbor(agent::A, model::ABM{<:ContinuousSpace,A}, r) where {A}
    n = nearby_ids(agent, model, r)
    d, j = Inf, 0
    for id in n
        dnew = euclidean_distance(agent.pos, model[id].pos, model)
        if dnew < d
            d, j = dnew, id
        end
    end
    if d == Inf
        return nothing
    else
        return model[j]
    end
end

using LinearAlgebra

"""
    elastic_collision!(a, b, f = nothing) → happened
Resolve a (hypothetical) elastic collision between the two agents `a, b`.
They are assumed to be disks of equal size touching tangentially.
Their velocities (field `vel`) are adjusted for an elastic collision happening between them.
This function works only for two dimensions.
Notice that collision only happens if both disks face each other, to avoid
collision-after-collision.

If `f` is a `Symbol`, then the agent property `f`, e.g. `:mass`, is taken as a mass
to weight the two agents for the collision. By default no weighting happens.

One of the two agents can have infinite "mass", and then acts as an immovable object
that specularly reflects the other agent. In this case momentum is not
conserved, but kinetic energy is still conserved.

Return a boolean encoding whether the collision happened.

Example usage in [Continuous space social distancing](
https://juliadynamics.github.io/AgentsExampleZoo.jl/dev/examples/social_distancing/).
"""
function elastic_collision!(a, b, f = nothing)
    # Do elastic collision according to
    # https://en.wikipedia.org/wiki/Elastic_collision#Two-dimensional_collision_with_two_moving_objects
    v1, v2, x1, x2 = a.vel, b.vel, a.pos, b.pos
    length(v1) ≠ 2 && error("This function works only for two dimensions.")
    r1 = x1 .- x2 # B to A
    n = norm(r1)^2
    n == 0 && return false # do nothing if they are at the same position
    dv = a.vel .- b.vel
    r2 = x2 .- x1 # A to B
    m1, m2 = f === nothing ? (1.0, 1.0) : (getfield(a, f), getfield(b, f))
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
        # Check if disks face or overtake each other, to avoid double collisions
        dot(dv, r2) ≤ 0 && return false
        f1 = (2m2 / (m1 + m2))
        f2 = (2m1 / (m1 + m2))
    end
    a.vel = v1 .- f1 .* (dot(dv, r1) / n) .* (r1)
    b.vel = v2 .+ f2 .* (dot(dv, r2) / n) .* (r2)
    return true
end

#######################################################################################
# interacting pairs
#######################################################################################
"""
    interacting_pairs(model, r, method; scheduler = model.scheduler) → piter
Return an iterator that yields **unique pairs** of agents `(a, b)` that are close
neighbors to each other, within some interaction radius `r`.

This function is usefully combined with `model_step!`, when one wants to perform
some pairwise interaction across all pairs of close agents once
(and does not want to trigger the event twice, both with `a` and with `b`, which
would be unavoidable when using `agent_step!`). This means, that if a pair
`(a, b)` exists, the pair `(b, a)` is not included in the iterator!

Use `piter.pairs` to get a vector of pair IDs from the iterator.

The argument `method` provides three pairing scenarios
- `:all`: return every pair of agents that are within radius `r` of each other,
  not only the nearest ones.
- `:nearest`: agents are only paired with their true nearest neighbor
  (existing within radius `r`).
  Each agent can only belong to one pair, therefore if two agents share the same nearest
  neighbor only one of them (sorted by distance, then by next id in `scheduler`) will be
  paired.
- `:types`: For mixed agent models only. Return every pair of agents within radius `r`
  (similar to `:all`), only capturing pairs of differing types. For example, a model of
  `Union{Sheep,Wolf}` will only return pairs of `(Sheep, Wolf)`. In the case of multiple
  agent types, e.g. `Union{Sheep, Wolf, Grass}`, skipping pairings that involve
  `Grass`, can be achived by a [`scheduler`](@ref Schedulers) that doesn't schedule `Grass`
  types, i.e.: `scheduler(model) = (a.id for a in allagents(model) if !(a isa Grass))`.

The following keywords can be used:
- `scheduler = model.scheduler`, which schedulers the agents during iteration for finding
  pairs. Especially in the `:nearest` case, this is important, as different sequencing
  for the agents may give different results (if `b` is the nearest agent for `a`, but
  `a` is not the nearest agent for `b`, whether you get the pair `(a, b)` or not depends
  on whether `a` was scheduelr first or not).
- `nearby_f = nearby_ids_exact` is the function that decides how to find nearby IDs
  in the `:all, :types` cases. Must be `nearby_ids_exact` or `nearby_ids`.

Example usage in [https://juliadynamics.github.io/AgentsExampleZoo.jl/dev/examples/growing_bacteria/](@ref).

!!! note "Better performance with CellListMap.jl"
    Notice that in most applications that [`interacting_pairs`](@ref) is useful, there is
    significant (10x-100x) performance gain to be made by integrating with CellListMap.jl.
    Checkout the [Integrating Agents.jl with CellListMap.jl](@ref) integration
    example for how to do this.

"""
function interacting_pairs(model::ABM{<:ContinuousSpace}, r::Real, method;
        scheduler = model.scheduler, nearby_f = nearby_ids_exact,
    )
    @assert method ∈ (:nearest, :all, :types)
    pairs = Tuple{Int,Int}[]
    if method == :nearest
        true_pairs!(pairs, model, r, scheduler)
    elseif method == :all
        all_pairs!(pairs, model, r, nearby_f)
    elseif method == :types
        type_pairs!(pairs, model, r, scheduler, nearby_f)
    end
    return PairIterator(pairs, model.agents)
end

function all_pairs!(
    pairs::Vector{Tuple{Int,Int}},
    model::ABM{<:ContinuousSpace},
    r::Real, nearby_f,
)
    for a in allagents(model)
        for nid in nearby_f(a, model, r)
            # Sort the pair to overcome any uniqueness issues
            new_pair = isless(a.id, nid) ? (a.id, nid) : (nid, a.id)
            new_pair ∉ pairs && push!(pairs, new_pair)
        end
    end
end

function true_pairs!(pairs::Vector{Tuple{Int,Int}}, model::ABM{<:ContinuousSpace}, r::Real, scheduler)
    distances = Vector{Float64}(undef, 0)
    for a in (model[id] for id in scheduler(model))
        nn = nearest_neighbor(a, model, r)
        nn === nothing && continue
        # Sort the pair to overcome any uniqueness issues
        new_pair = isless(a.id, nn.id) ? (a.id, nn.id) : (nn.id, a.id)
        if new_pair ∉ pairs
            # We also need to check if our current pair is closer to each
            # other than any pair using our first id already in the list,
            # so we keep track of nn distances.
            dist = euclidean_distance(a.pos, nn.pos, model)

            idx = findfirst(x -> first(new_pair) == x, first.(pairs))
            if idx === nothing
                push!(pairs, new_pair)
                push!(distances, dist)
            elseif idx !== nothing && distances[idx] > dist
                # Replace this pair, it is not the true neighbor
                pairs[idx] = new_pair
                distances[idx] = dist
            end
        end
    end
    to_remove = Int[]
    for doubles in symdiff(unique(Iterators.flatten(pairs)), collect(Iterators.flatten(pairs)))
        # This list is the set of pairs that have two distances in the pair list.
        # The one with the largest distance value must be dropped.
        fidx = findfirst(isequal(doubles), first.(pairs))
        if fidx !== nothing
            lidx = findfirst(isequal(doubles), last.(pairs))
            largest = distances[fidx] <= distances[lidx] ? lidx : fidx
            push!(to_remove, largest)
        else
            # doubles are not from first sorted, there could be more than one.
            idxs = findall(isequal(doubles), last.(pairs))
            to_keep = findmin(map(i->distances[i], idxs))[2]
            deleteat!(idxs, to_keep)
            append!(to_remove, idxs)
        end
    end
    deleteat!(pairs, unique!(sort!(to_remove)))
end

function type_pairs!(
    pairs::Vector{Tuple{Int,Int}},
    model::ABM{<:ContinuousSpace},
    r::Real, scheduler, nearby_f,
)
    # We don't know ahead of time what types the scheduler will provide. Get a list.
    available_types = unique(typeof(model[id]) for id in scheduler(model))
    for id in scheduler(model)
        for nid in nearby_f(model[id], model, r)
            neigbor_type = typeof(model[nid])
            if neigbor_type ∈ available_types && neigbor_type !== typeof(model[id])
                # Sort the pair to overcome any uniqueness issues
                new_pair = isless(id, nid) ? (id, nid) : (nid, id)
                new_pair ∉ pairs && push!(pairs, new_pair)
            end
        end
    end
end

struct PairIterator{A}
    pairs::Vector{Tuple{Int,Int}}
    agents::Dict{Int,A}
end

Base.eltype(::PairIterator{A}) where {A} = Tuple{A, A}
Base.length(iter::PairIterator) = length(iter.pairs)
function Base.iterate(iter::PairIterator, i = 1)
    i > length(iter) && return nothing
    p = iter.pairs[i]
    id1, id2 = p
    return (iter.agents[id1], iter.agents[id2]), i + 1
end


#######################################################################################
# Spatial fields
#######################################################################################
export get_spatial_property, get_spatial_index
"""
    get_spatial_property(pos::NTuple{D, Float64}, property::AbstractArray, model::ABM)
Convert the continuous agent position into an appropriate `index` of `property`, which
represents some discretization of a spatial field over a [`ContinuousSpace`](@ref).
Then, return `property[index]`. To get the `index` directly, for e.g. mutating the
`property` in-place, use [`get_spatial_index`](@ref).
"""
function get_spatial_property(pos, property::AbstractArray, model::ABM)
    index = get_spatial_index(pos, property, model)
    return property[index]
end

"""
    get_spatial_property(pos::NTuple{D, Float64}, property::Function, model::ABM)
Literally equivalent with `property(pos, model)`, provided just for syntax consistency.
"""
get_spatial_property(pos, property, model::ABM) = property(pos, model)

"""
    get_spatial_index(pos, property::AbstractArray, model::ABM)
Convert the continuous agent position into an appropriate `index` of `property`, which
represents some discretization of a spatial field over a [`ContinuousSpace`](@ref).

The dimensionality of `property` and the continuous space do not have to match.
If `property` has lower dimensionalty than the space (e.g. representing some surface
property in 3D space) then the front dimensions of `pos` will be used to index.
"""
function get_spatial_index(pos, property::AbstractArray{T,D}, model::ABM) where {T,D}
    ssize = spacesize(model)
    propertysize = size(property)
    upos = pos[1:D]
    usize = ssize[1:D]
    εs = usize ./ propertysize
    idxs = floor.(Int, upos ./ εs) .+ 1
    return CartesianIndex(idxs)
end

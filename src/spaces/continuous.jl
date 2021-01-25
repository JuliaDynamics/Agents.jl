export ContinuousSpace

struct ContinuousSpace{D,P,T<:AbstractFloat,F} <: AbstractSpace
    grid::GridSpace{D,P}
    update_vel!::F
    dims::NTuple{D,Int}
    spacing::T
    extent::NTuple{D,T}
end
Base.eltype(s::ContinuousSpace{D,P,T,F}) where {D,P,T,F} = T
defvel(a, m) = nothing

"""
    ContinuousSpace(extent::NTuple{D, <:Real}, spacing = min(extent...)/10; kwargs...)
Create a `D`-dimensional `ContinuousSpace` in range 0 to (but not including) `extent`.
`spacing` configures the compartment spacing that the space is divided in, in order to
accelerate nearest neighbor functions like [`nearby_ids`](@ref).
All dimensions in `extent` must be completely divisible by `spacing` (i.e. no
fractional remainder).
Your agent positions (field `pos`) must be of type `NTuple{D, <:Real}`,
use [`ContinuousAgent`](@ref) for convenience.
In addition it is useful for agents to have a field `vel::NTuple{D, <:Real}` to use
in conjunction with [`move_agent!`](@ref).

The keyword `periodic = true` configures whether the space is periodic or not. If set to
`false` an error will occur if an agent's position exceeds the boundary.

The keyword argument `update_vel!` is a **function**, `update_vel!(agent, model)` that updates
the agent's velocity **before** the agent has been moved, see [`move_agent!`](@ref).
You can of course change the agents' velocities
during the agent interaction, the `update_vel!` functionality targets spatial force
fields acting on the agents individually (e.g. some magnetic field).
By default no update is done this way.
If you use `update_vel!`, the agent type must have a field `vel::NTuple{D, <:Real}`.

There is no "best" choice for the value of `spacing`. If you need optimal performance it's
advised to set up a benchmark over a range of choices. The value matters most when searching
for neighbors. In [`Models.flocking`](@ref) for example, an optimal value for `spacing` is
66% of the search distance.
"""
function ContinuousSpace(
    extent::NTuple{D,X},
    spacing = min(extent...) / 10.0;
    update_vel! = defvel,
    periodic = true,
) where {D,X<:Real}
    @assert extent ./ spacing == floor.(extent ./ spacing) "All dimensions in `extent` must be completely divisible by `spacing`"
    s = GridSpace(floor.(Int, extent ./ spacing), periodic = periodic, metric = :euclidean)
    Z = X <: AbstractFloat ? X : Float64
    return ContinuousSpace(s, update_vel!, size(s), Z(spacing), Z.(extent))
end

function random_position(model::ABM{<:ContinuousSpace})
    map(dim -> rand() * dim, model.space.extent)
end

pos2cell(pos::Tuple, model::ABM) = floor.(Int, pos ./ model.space.spacing) .+ 1
pos2cell(a::AbstractAgent, model::ABM) = pos2cell(a.pos, model)
function cell_center(pos::NTuple{D,F}, model) where {D,F}
    ε = model.space.spacing
    (pos2cell(pos, model) .- 1) .* ε .+ ε / 2
end
distance_from_cell_center(pos, model::ABM) =
    distance_from_cell_center(pos, cell_center(pos, model))
function distance_from_cell_center(pos::Tuple, center::Tuple)
    sqrt(sum(abs2.(pos .- center)))
end

function add_agent_to_space!(a::A, model::ABM{<:ContinuousSpace,A}) where {A<:AbstractAgent}
    push!(model.space.grid.s[pos2cell(a, model)...], a.id)
    return a
end

function remove_agent_from_space!(
    a::A,
    model::ABM{<:ContinuousSpace,A},
) where {A<:AbstractAgent}
    prev = model.space.grid.s[pos2cell(a, model)...]
    ai = findfirst(i -> i == a.id, prev)
    deleteat!(prev, ai)
    return a
end

function move_agent!(
    a::A,
    pos::Tuple,
    model::ABM{<:ContinuousSpace{D,periodic},A},
) where {A<:AbstractAgent,D,periodic}
    remove_agent_from_space!(a, model)
    if periodic
        pos = mod.(pos, model.space.extent)
    end
    a.pos = pos
    add_agent_to_space!(a, model)
end

"""
    move_agent!(agent::A, model::ABM{<:ContinuousSpace,A}, dt::Real = 1.0)
Propagate the agent forwards one step according to its velocity,
_after_ updating the agent's velocity (if configured, see [`ContinuousSpace`](@ref)).
Also take care of periodic boundary conditions.

For this continuous space version of `move_agent!`, the "evolution algorithm"
is a trivial Euler scheme with `dt` the step size, i.e. the agent position is updated
as `agent.pos += agent.vel * dt`. If you want to move the agent to a specified position, do
`move_agent!(agent, pos, model)`.
"""
function move_agent!(
    agent::A,
    model::ABM{<:ContinuousSpace,A},
    dt::Real = 1.0,
) where {A<:AbstractAgent}
    model.space.update_vel!(agent, model)
    pos = agent.pos .+ dt .* agent.vel
    move_agent!(agent, pos, model)
    return agent.pos
end

#######################################################################################
# %% Neighbors and stuff
#######################################################################################
function nearby_ids(
    pos::ValidPos,
    model::ABM{<:ContinuousSpace{D,A,T}},
    r = 1;
    exact = false,
) where {D,A,T}
    if exact
        grid_r_max = r < model.space.spacing ? T(1) : r / model.space.spacing + T(1)
        grid_r_certain = grid_r_max - T(1.2) * sqrt(D)
        focal_cell = CartesianIndex(pos2cell(pos, model))
        allcells = grid_space_neighborhood(focal_cell, model, grid_r_max)
        if grid_r_max >= 1
            certain_cells = grid_space_neighborhood(focal_cell, model, grid_r_certain)
            certain_ids =
                Iterators.flatten(ids_in_position(cell, model) for cell in certain_cells)

            uncertain_cells = setdiff(allcells, certain_cells) # This allocates, but not sure if there's a better way.
            uncertain_ids =
                Iterators.flatten(ids_in_position(cell, model) for cell in uncertain_cells)

            additional_ids = Iterators.filter(
                i -> edistance(pos, model[i].pos, model) ≤ r,
                uncertain_ids,
            )

            return Iterators.flatten((certain_ids, additional_ids))
        else
            all_ids = Iterators.flatten(ids_in_position(cell, model) for cell in allcells)
            return Iterators.filter(i -> edistance(pos, model[i].pos, model) ≤ r, all_ids)
        end
    else
        δ = distance_from_cell_center(pos, cell_center(pos, model))
        grid_r = (r + δ) / model.space.spacing
        return nearby_ids_cell(pos, model, grid_r)
    end
end

grid_space_neighborhood(α, model::ABM{<:ContinuousSpace}, r) =
    grid_space_neighborhood(α, model.space.grid, r)

function nearby_ids_cell(pos::ValidPos, model::ABM{<:ContinuousSpace}, r = 1)
    nn = grid_space_neighborhood(CartesianIndex(pos2cell(pos, model)), model, r)
    s = model.space.grid.s
    Iterators.flatten((s[i...] for i in nn))
end

function nearby_positions(pos::ValidPos, model::ABM{<:ContinuousSpace}, r = 1)
    nn = grid_space_neighborhood(CartesianIndex(pos2cell(pos, model)), model, r)
    Iterators.filter(!isequal(pos), nn)
end

function positions(model::ABM{<:ContinuousSpace})
    x = CartesianIndices(model.space.grid.s)
    return (Tuple(y) for y in x)
end

function ids_in_position(pos::ValidPos, model::ABM{<:ContinuousSpace})
    return model.space.grid.s[pos...]
end

################################################################################
### Pretty printing
################################################################################
function Base.show(io::IO, space::ContinuousSpace{D,P}) where {D,P}
    s = "$(P ? "periodic" : "") continuous space with $(join(space.dims, "×")) divisions"
    space.update_vel! ≠ defvel && (s *= " with velocity updates")
    print(io, s)
end

#######################################################################################
# Continuous space exclusive
#######################################################################################
export nearest_neighbor, elastic_collision!, interacting_pairs

"""
    nearest_neighbor(agent, model::ABM{<:ContinuousSpace}, r) → nearest
Return the agent that has the closest distance to given `agent`.
Return `nothing` if no agent is within distance `r`.
"""
function nearest_neighbor(
    agent::A,
    model::ABM{<:ContinuousSpace,A},
    r;
    exact = false,
) where {A}
    n = collect(nearby_ids(agent, model, r; exact))
    length(n) == 0 && return nothing
    d, j = Inf, 1
    for i in 1:length(n)
        @inbounds dnew = edistance(agent.pos, model[n[i]].pos, model)
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

Example usage in [Continuous space social distancing for COVID-19](@ref).
"""
function elastic_collision!(a, b, f = nothing)
    # Do elastic collision according to
    # https://en.wikipedia.org/wiki/Elastic_collision#Two-dimensional_collision_with_two_moving_objects
    v1, v2, x1, x2 = a.vel, b.vel, a.pos, b.pos
    length(v1) ≠ 2 && error("This function works only for two dimensions.")
    r1 = x1 .- x2
    r2 = x2 .- x1
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
        f1 = (2m2 / (m1 + m2))
        f2 = (2m1 / (m1 + m2))
    end
    ken = norm(v1)^2 + norm(v2)^2
    dx = a.pos .- b.pos
    dv = a.vel .- b.vel
    n = norm(dx)^2
    n == 0 && return false # do nothing if they are at the same position
    a.vel = v1 .- f1 .* (dot(v1 .- v2, r1) / n) .* (r1)
    b.vel = v2 .- f2 .* (dot(v2 .- v1, r2) / n) .* (r2)
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
  neighbor only one of them (sorted by distance, then by next id in `scheduler`) will be
  paired.
- `:types`: For mixed agent models only. Return every pair of agents within radius `r`
  (similar to `:all`), only capturing pairs of differing types. For example, a model of
  `Union{Sheep,Wolf}` will only return pairs of `(Sheep, Wolf)`. In the case of multiple
  agent types, *e.g.* `Union{Sheep, Wolf, Grass}`, skipping pairings that involve
  `Grass`, can be achived by a [`scheduler`](@ref Schedulers) that doesn't schedule `Grass`
  types, *i.e.*: `scheduler(model) = (a.id for a in allagents(model) if !(a isa Grass))`.

Example usage in [Bacterial Growth](@ref).
"""
function interacting_pairs(
    model::ABM{<:ContinuousSpace},
    r::Real,
    method;
    scheduler = model.scheduler,
    exact = true,
)
    @assert method ∈ (:nearest, :all, :types)
    pairs = Tuple{Int,Int}[]
    if method == :nearest
        true_pairs!(pairs, model, r, scheduler)
    elseif method == :all
        all_pairs!(pairs, model, r, exact = exact)
    elseif method == :types
        type_pairs!(pairs, model, r, scheduler, exact = exact)
    end
    return PairIterator(pairs, model.agents)
end

function all_pairs!(
    pairs::Vector{Tuple{Int,Int}},
    model::ABM{<:ContinuousSpace},
    r::Real;
    exact = true,
)
    for a in allagents(model)
        for nid in nearby_ids(a, model, r; exact)
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
        nn == nothing && continue
        # Sort the pair to overcome any uniqueness issues
        new_pair = isless(a.id, nn.id) ? (a.id, nn.id) : (nn.id, a.id)
        if new_pair ∉ pairs
            # We also need to check if our current pair is closer to each
            # other than any pair using our first id already in the list,
            # so we keep track of nn distances.
            dist = edistance(a.pos, nn.pos, model)

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
    to_remove = Int[]
    for doubles in symdiff(unique(Iterators.flatten(pairs)), collect(Iterators.flatten(pairs)))
        # This list is the set of pairs that have two distances in the pair list.
        # The one with the largest distance value must be dropped.
        fidx = findfirst(isequal(doubles), first.(pairs))
        if fidx != nothing
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
    r::Real,
    scheduler;
    exact = true,
)
    # We don't know ahead of time what types the scheduler will provide. Get a list.
    available_types = unique(typeof(model[id]) for id in scheduler(model))
    for id in scheduler(model)
        for nid in nearby_ids(model[id], model, r, exact = exact)
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

Base.length(iter::PairIterator) = length(iter.pairs)
function Base.iterate(iter::PairIterator, i = 1)
    i > length(iter) && return nothing
    p = iter.pairs[i]
    id1, id2 = p
    return (iter.agents[id1], iter.agents[id2]), i + 1
end

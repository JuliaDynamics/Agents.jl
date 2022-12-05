export euclidean_distance, manhattan_distance, get_direction, normalize_position, walk!, Arccos, randomwalk!, spacesize

using Distributions, Rotations, StaticArrays

#######################################################################################
# %% Distances and directions in Grid/Continuous space
#######################################################################################
"""
    euclidean_distance(a, b, model::ABM)

Return the euclidean distance between `a` and `b` (either agents or agent positions),
respecting periodic boundary conditions (if in use). Works with any space where it makes
sense: currently `AbstractGridSpace` and `ContinuousSpace`.

Example usage in the [Flocking model](@ref).
"""
euclidean_distance(
    a::A,
    b::B,
    model::ABM{<:Union{ContinuousSpace,AbstractGridSpace}},
) where {A <: AbstractAgent,B <: AbstractAgent} = euclidean_distance(a.pos, b.pos, model)

function euclidean_distance(
    p1::ValidPos,
    p2::ValidPos,
    model::ABM{<:Union{ContinuousSpace{D,false},AbstractGridSpace{D,false}}},
) where {D}
    sqrt(sum(abs2.(p1 .- p2)))
end

function euclidean_distance(
    p1::ValidPos,
    p2::ValidPos,
    model::ABM{<:ContinuousSpace{D,true}},
) where {D}
    total = 0.0
    for (a, b, d) in zip(p1, p2, spacesize(model))
        delta = abs(b - a)
        if delta > d - delta
            delta = d - delta
        end
        total += delta^2
    end
    sqrt(total)
end

function euclidean_distance(
        p1::ValidPos, p2::ValidPos, model::ABM{<:AbstractGridSpace{D,true}}
    ) where {D}
    total = 0.0
    for (a, b, d) in zip(p1, p2, size(model.space))
        delta = abs(b - a)
        if delta > d - delta
            delta = d - delta
        end
        total += delta^2
    end
    sqrt(total)
end

"""
    manhattan_distance(a, b, model::ABM)

Return the manhattan distance between `a` and `b` (either agents or agent positions),
respecting periodic boundary conditions (if in use). Works with any space where it makes
sense: currently `AbstractGridSpace` and `ContinuousSpace`.
"""
manhattan_distance(
    a::A,
    b::B,
    model::ABM{<:Union{ContinuousSpace,AbstractGridSpace}},
) where {A <: AbstractAgent,B <: AbstractAgent} = manhattan_distance(a.pos, b.pos, model)

function manhattan_distance(
    p1::ValidPos,
    p2::ValidPos,
    model::ABM{<:Union{ContinuousSpace{D,false},AbstractGridSpace{D,false}}},
) where {D}
    sum(abs.(p1 .- p2))
end

function manhattan_distance(
    p1::ValidPos,
    p2::ValidPos,
    model::ABM{<:Union{ContinuousSpace{D,true},AbstractGridSpace{D,true}}}
) where {D}
    total = 0.0
    # find minimum distance for each dimension, add to total
    for dim in 1:D
        direct = abs(p1[dim] - p2[dim])
        total += min(size(model.space)[dim] - direct, direct)
    end
    return total
end

"""
    get_direction(from, to, model::ABM)
Return the direction vector from the position `from` to position `to` taking into account
periodicity of the space.
"""
get_direction(from, to, model::ABM) = get_direction(from, to, model.space)
# Periodic spaces version
function get_direction(
    from::NTuple{D,Float64},
    to::NTuple{D,Float64},
    space::Union{ContinuousSpace{D,true},AbstractGridSpace{D,true}}
) where {D}
    best = to .- from
    for offset in Iterators.product([-1:1 for _ in 1:D]...)
        dir = to .+ offset .* spacesize(space) .- from
        sum(dir.^2) < sum(best.^2) && (best = dir)
    end
    return best
end

function get_direction(from, to, ::Union{AbstractGridSpace,ContinuousSpace})
    return to .- from
end

#######################################################################################
# %% Utilities for graph-based spaces (Graph/OpenStreetMap)
#######################################################################################
GraphBasedSpace = Union{GraphSpace,OpenStreetMapSpace}
_get_graph(space::GraphSpace) = space.graph
_get_graph(space::OpenStreetMapSpace) = space.map.graph
"""
    nv(model::ABM)
Return the number of positions (vertices) in the `model` space.
"""
Graphs.nv(abm::ABM{<:GraphBasedSpace}) = Graphs.nv(_get_graph(abm.space))

"""
    ne(model::ABM)
Return the number of edges in the `model` space.
"""
Graphs.ne(abm::ABM{<:GraphBasedSpace}) = Graphs.ne(_get_graph(abm.space))

positions(model::ABM{<:GraphBasedSpace}) = 1:nv(model)

function nearby_positions(
    position::Integer,
    model::ABM{<:GraphBasedSpace},
    radius::Integer;
    kwargs...,
)
    output = copy(nearby_positions(position, model; kwargs...))
    for _ in 2:radius
        newnps = (nearby_positions(np, model; kwargs...) for np in output)
        append!(output, reduce(vcat, newnps))
        unique!(output)
    end
    filter!(i -> i ≠ position, output)
end

#######################################################################################
# %% Walking
#######################################################################################
"""
    normalize_position(pos, model::ABM{<:Union{AbstractGridSpace,ContinuousSpace}})

Return the position `pos` normalized for the extents of the space of the given `model`.
For periodic spaces, this wraps the position along each dimension, while for non-periodic
spaces this clamps the position to the space extent.
"""
normalize_position(pos, model::ABM) = normalize_position(pos, model.space)

function normalize_position(pos, space::ContinuousSpace{D,true}) where {D}
    return mod.(pos, spacesize(space))
end

function normalize_position(pos, space::ContinuousSpace{D,false}) where {D}
    ss = spacesize(space)
    return Tuple(clamp.(pos, 0.0, prevfloat.(ss)))
end

function normalize_position(pos, space::AbstractGridSpace{D,true}) where {D}
    return mod1.(pos, spacesize(space))
end

function normalize_position(pos, space::AbstractGridSpace{D,false}) where {D}
    return Tuple(clamp.(pos, ones(Int, D), spacesize(space)))
end

"""
    walk!(agent, direction::NTuple, model; ifempty = true)

Move agent in the given `direction` respecting periodic boundary conditions.
For non-periodic spaces, agents will walk to, but not exceed the boundary value.
Available for both `AbstractGridSpace` and `ContinuousSpace`s.

The type of `direction` must be the same as the space position. `AbstractGridSpace` asks
for `Int`, and `ContinuousSpace` for `Float64` tuples, describing the walk distance in
each direction. `direction = (2, -3)` is an example of a valid direction on a
`AbstractGridSpace`, which moves the agent to the right 2 positions and down 3 positions.
Agent velocity is ignored for this operation in `ContinuousSpace`.

## Keywords
- `ifempty` will check that the target position is unoccupied and only move if that's true.
  Available only on `AbstractGridSpace`.

Example usage in [Battle Royale](
    https://juliadynamics.github.io/AgentsExampleZoo.jl/dev/examples/battle/).
"""
function walk!(
    agent::AbstractAgent,
    direction::NTuple{D,Int},
    model::ABM{<:AbstractGridSpace};
    ifempty::Bool = true
) where {D}
    target = normalize_position(agent.pos .+ direction, model)
    if !ifempty || isempty(ids_in_position(target, model))
        move_agent!(agent, target, model)
    end
end

function walk!(
    agent::AbstractAgent,
    direction::NTuple{D,Float64},
    model::ABM{<:ContinuousSpace}
) where {D}
    target = normalize_position(agent.pos .+ direction, model)
    move_agent!(agent, target, model)
end

"""
    walk!(agent, rand, model)

Invoke a random walk by providing the `rand` function in place of
`direction`. For `AbstractGridSpace`, the walk will cover ±1 positions in all directions,
`ContinuousSpace` will reside within [-1, 1].
"""
walk!(agent, ::typeof(rand), model::ABM{<:AbstractGridSpace{D}}; kwargs...) where {D} =
    walk!(agent, Tuple(rand(model.rng, -1:1, D)), model; kwargs...)

walk!(agent, ::typeof(rand), model::ABM{<:ContinuousSpace{D}}) where {D} =
    walk!(agent, Tuple(2.0 * rand(model.rng) - 1.0 for _ in 1:D), model)

"""
    randomwalk!(agent, model::ABM{<:AbstractGridSpace}, r)
Move `agent` for a distance `r` in a random direction respecting boundary conditions
and space metric.
For Chebyshev and Manhattan metric, the step size `r` is rounded to `floor(Int,r)`;
for Euclidean metric in a GridSpace, random walks are not defined due to a strong
dependency on the given value of `r`.
"""
function randomwalk!(
    agent::AbstractAgent,
    model::ABM{<:AbstractGridSpace},
    r::Real
)
    if model.space.metric == :euclidean
        throw(ArgumentError(
            "Random walks on a GridSpace with Euclidean metric are not defined. " *
            "You might want to use a ContinuousSpace or a different metric."
        ))
    end
    offsets = offsets_at_radius(model, r)
    # if ifempty is not set to false, `walk!` will error for GridSpaceSingle
    ifempty = typeof(model.space) <: GridSpaceSingle ? false : true
    walk!(agent, rand(offsets), model; ifempty)
end


"""
    rotate(w::SVector{2}, θ::Real)
Rotate two-dimensional vector `w` by an angle `θ`.
The angle must be given in radians.
"""
rotate(w::SVector{2}, θ::Real) = Angle2d(θ) * w

"""
    rotate(w::SVector{3}, θ::Real, ϕ::Real)
Rotate three-dimensional vector `w` by angles `θ` (polar) and `ϕ` (azimuthal).
The angles must be given in radians.

Note that in general a 3D rotation requires 1 angle and 1 axis of rotation (or 3 angles).
Here, using only 2 angles, `w` is first rotated by angle `θ`
about an arbitrarily chosen vector (`u`) normal to it (`u⋅w=0`);
this new rotated vector (`a`) is then rotated about the original `w` by the angle `ϕ`.
The resulting vector (`v`) satifies (v⋅w)/(|v|*|w|) = cos(θ) ∀ ϕ.
"""
function rotate(w::SVector{3}, θ::Real, ϕ::Real)
    # find a vector normal to w
    m = findfirst(w .≠ 0)
    n = m%3 + 1
    u = SVector{3}(0., 0., 0.)
    u = setindex(u, w[m], n)
    u = setindex(u, -w[n], m)
    # rotate w around u by the polar angle θ
    a = AngleAxis(θ, u...) * w
    # rotate a around the original vector w by the azimuthal angle ϕ
    AngleAxis(ϕ, w...) * a
end # function

"""
    randomwalk!(agent, model::ABM{<:ContinuousSpace{2}}, r; polar=Uniform(-π,π))
Move `agent` for a distance `r` in a random direction, respecting 
boundary conditions and space metric.
The new direction is chosen from the angle distribution `polar`, which defaults
to a uniform distribution in the plane.
"""
function randomwalk!(
    agent::AbstractAgent,
    model::ABM{<:ContinuousSpace{2}},
    r::Real;
    polar=Uniform(-π,π),
)
    θ = rand(polar)
    r₀ = LinearAlgebra.norm(agent.vel)
    direction = Tuple(rotate(SVector(agent.vel), θ)) .* (r / r₀)
    agent.vel = direction
    walk!(agent, direction, model)
end

# define new distribution to obtain spherically uniform rotations in 3D
struct Arccos{T<:Real} <: ContinuousUnivariateDistribution
    a::T
    b::T
    Arccos{T}(a::T,b::T) where {T} = new{T}(a::T,b::T)
end
"""
    Arccos(a, b)
Create a ContinuousUnivariateDistribution corresponding to `acos(Uniform(a,b))`.
"""
function Arccos(a::Real, b::Real; check_args::Bool=true)
    Distributions.@check_args Arccos a<b -1≤a≤1 -1≤b≤1
    return Arccos{Float64}(Float64(a), Float64(b))
end
Arccos() = Arccos(-1,1)
Base.rand(rng::AbstractRNG, d::Arccos) = acos(rand(rng, Uniform(d.a, d.b)))

"""
    randomwalk!(agent, model::ABM{<:ContinuousSpace{3}}, r; polar=Uniform(-π,π), azimuthal=Arccos(-1,1))
Move `agent` for a distance `r` in a random direction, respecting boundary conditions
and space metric.
The displacement `r` must be larger than 0.
The new direction is chosen from the angle distributions `polar` and `azimuthal`;
their default values produce uniformly distributed reorientations on the unit sphere.
"""
function randomwalk!(
    agent::AbstractAgent,
    model::ABM{<:ContinuousSpace{3}},
    r::Real;
    polar=Uniform(-π,π),
    azimuthal=Arccos(-1,1),
)
    if r ≤ 0
        throw(ArgumentError("The displacement must be larger than 0."))
    end
    θ = rand(polar)
    ϕ = rand(azimuthal)
    r₀ = LinearAlgebra.norm(agent.vel)
    direction = Tuple(rotate(SVector(agent.vel), θ, ϕ)) .* (r / r₀)
    agent.vel = direction
    walk!(agent, direction, model)
end

"""
    spacesize(model::ABM)

Return the size of the model's space. Works for [`AbstractGridSpace`](@ref) and
[`ContinuousSpace`](@ref).
"""
spacesize(model::ABM) = spacesize(model.space)

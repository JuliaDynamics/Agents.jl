using Distributions: Distributions, Uniform, ContinuousUnivariateDistribution
using Rotations
using StaticArrays: SVector, setindex

export walk!, randomwalk!, normalize_position
export Arccos, Uniform

#######################################################################################
# %% Walking
#######################################################################################
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
    if !ifempty || isempty(target, model)
        move_agent!(agent, target, model)
    end
    return agent
end

function walk!(
    agent::AbstractAgent,
    direction::NTuple{D,Int},
    model::ABM{<:GridSpaceSingle}
) where {D}
    target = normalize_position(agent.pos .+ direction, model)
    if isempty(target, model) # if target unoccupied
        move_agent!(agent, target, model)
    end
    return agent
end

function walk!(
    agent::AbstractAgent,
    direction::NTuple{D,Float64},
    model::ABM{<:ContinuousSpace}
) where {D}
    target = normalize_position(agent.pos .+ direction, model)
    move_agent!(agent, target, model)
    return agent
end

"""
    normalize_position(pos, model::ABM{<:Union{AbstractGridSpace,ContinuousSpace}})

Return the position `pos` normalized for the extents of the space of the given `model`.
For periodic spaces, this wraps the position along each dimension, while for non-periodic
spaces this clamps the position to the space extent.
"""
normalize_position(pos, model::ABM) = normalize_position(pos, abmspace(model))

function normalize_position(pos::ValidPos, space::ContinuousSpace{D,true}) where {D}
    return mod.(pos, spacesize(space))
end

function normalize_position(pos::ValidPos, space::ContinuousSpace{D,false}) where {D}
    return clamp.(pos, 0.0, prevfloat.(spacesize(space)))
end

function normalize_position(pos::ValidPos, space::AbstractGridSpace{D,true}) where {D}
    return mod1.(pos, spacesize(space))
end

function normalize_position(pos::ValidPos, space::AbstractGridSpace{D,false}) where {D}
    return clamp.(pos, 1, spacesize(space))
end

#######################################################################################
# %% Random walks
#######################################################################################


"""
    randomwalk!(agent, model::ABM{<:AbstractGridSpace}, r::Real = 1; kwargs...)

Move `agent` for a distance `r` in a random direction respecting boundary conditions
and space metric. For Chebyshev and Manhattan metric, the step size `r` is rounded to 
`floor(Int,r)`; for Euclidean metric in a GridSpace, random walks are ill defined 
and hence not supported.

For example, for `Chebyshev` metric and `r=1`, this will move the agent with equal
probability to any of the 8 surrounding cells. For Manhattan metric, it
will move to any of the 4 surrounding cells.

## Keywords
- `ifempty` will check that the target position is unoccupied and only move if that's true.
  So if `ifempty` is true, this can resultin the agent not moving even if there are available 
  positions. By default this is true, set it to false if different agents can occupy the same 
  position. In a `GridSpaceSingle`, agents cannot overlap anyways and this keyword has no effect.
- `force_motion` has an effect only if `ifempty` is true or the space is a `GridSpaceSingle`. 
  If set to true, the search for the random walk will be done only on the empty positions, 
  so in this case the agent will move if there is at least one empty position to choose from. 
  By default this is false.
"""
function randomwalk!(
    agent::AbstractAgent,
    model::ABM{<:AbstractGridSpace},
    r::Real = 1;
    ifempty = true,
    force_motion = false
)
    if abmspace(model).metric == :euclidean
        throw(ArgumentError(
            "Random walks on a `GridSpace` with Euclidean metric are not defined. " *
            "You might want to use a `ContinuousSpace` or a different metric."
        ))
    end
    offsets = offsets_at_radius(model, r)
    if ifempty && force_motion
        n_attempts = 2*length(offsets)
        while n_attempts != 0
            pos_choice = normalize_position(agent.pos .+ rand(abmrng(model), offsets), model)
            isempty(pos_choice, model) && return move_agent!(agent, pos_choice, model)
            n_attempts -= 1
        end
        targets = Iterators.map(β -> normalize_position(agent.pos .+ β, model), offsets)
        check_empty = pos -> isempty(pos, model)
        pos_choice = sampling_with_condition_single(targets, check_empty, model)
        isnothing(pos_choice) && return agent
        walk!(agent, pos_choice, model; ifempty=ifempty)
    else
        walk!(agent, rand(abmrng(model), offsets), model; ifempty=ifempty)
    end
end

function randomwalk!(
    agent::AbstractAgent,
    model::ABM{<:GridSpaceSingle},
    r::Real = 1;
    ifempty = true,
    force_motion = false
)
    if abmspace(model).metric == :euclidean
        throw(ArgumentError(
            "Random walks on a `GridSpace` with Euclidean metric are not defined. " *
            "You might want to use a `ContinuousSpace` or a different metric."
        ))
    end
    offsets = offsets_at_radius(model, r)
    if force_motion
        n_attempts = 2*length(offsets)
        while n_attempts != 0
            pos_choice = normalize_position(agent.pos .+ rand(abmrng(model), offsets), model)
            isempty(pos_choice, model) && return move_agent!(agent, pos_choice, model)
            n_attempts -= 1
        end
        targets = Iterators.map(β -> normalize_position(agent.pos .+ β, model), offsets)
        check_empty = pos -> isempty(pos, model)
        pos_choice = sampling_with_condition_single(targets, check_empty, model)
        isnothing(pos_choice) && return agent
        walk!(agent, pos_choice, model)
    else
        walk!(agent, rand(abmrng(model), offsets), model)
    end
end

"""
    randomwalk!(agent, model::ABM{<:ContinuousSpace} [, r];
        [polar=Uniform(-π,π), azimuthal=Arccos(-1,1)]
    )

Re-orient and move `agent` for a distance `r` in a random direction
respecting space boundary conditions. By default `r = norm(agent.vel)`.

The `ContinuousSpace` version is slightly different than the grid space.
Here, the agent's velocity is updated by the random vector generated for
the random walk. 

Uniform/isotropic random walks are supported in any number of dimensions
while an angles distribution can be specified for 2D and 3D random walks.
In this case, the velocity vector is rotated using random angles given by 
the distributions for polar (2D and 3D) and azimuthal (3D only) angles, and 
scaled to have measure `r`. After the re-orientation the agent is moved for 
`r` in the new direction.

Anything that supports `rand` can be used as an angle distribution instead. 
This can be useful to create correlated random walks.
"""
function randomwalk!(
    agent::AbstractAgent,
    model::ABM{<:ContinuousSpace{D}},
    r::Real;
) where {D}
    return uniform_randomwalk!(agent, model, r)
end

function randomwalk!(
    agent::AbstractAgent,
    model::ABM{<:ContinuousSpace{D}},
) where {D}
    return uniform_randomwalk!(agent, model)
end

function randomwalk!(
    agent::AbstractAgent,
    model::ABM{<:ContinuousSpace{2}},
    r::Real;
    polar=nothing,
)
    if isnothing(polar)
        return uniform_randomwalk!(agent, model, r)
    end
    if r ≤ 0
        throw(ArgumentError("The displacement must be larger than 0."))
    end
    θ = rand(abmrng(model), polar)
    relative_r = r/LinearAlgebra.norm(agent.vel)
    direction = Tuple(rotate(SVector(agent.vel), θ)) .* relative_r
    agent.vel = direction
    walk!(agent, direction, model)
end

# Code degeneracy here but makes much faster version without r
function randomwalk!(
    agent::AbstractAgent,
    model::ABM{<:ContinuousSpace{2}};
    polar=nothing,
)
    if isnothing(polar)
        return uniform_randomwalk!(agent, model)
    end
    θ = rand(abmrng(model), polar)
    direction = Tuple(rotate(SVector(agent.vel), θ))
    agent.vel = direction
    walk!(agent, direction, model)
end

function randomwalk!(
    agent::AbstractAgent,
    model::ABM{<:ContinuousSpace{3}},
    r::Real;
    polar=nothing,
    azimuthal=nothing,
)
    if isnothing(polar) && isnothing(azimuthal)
        return uniform_randomwalk!(agent, model, r)
    end
    if r ≤ 0
        throw(ArgumentError("The displacement must be larger than 0."))
    end
    θ = rand(abmrng(model), isnothing(polar) ? Uniform(-π,π) : polar)
    ϕ = rand(abmrng(model), isnothing(azimuthal) ? Arccos(-1,1) : azimuthal)
    relative_r = r/LinearAlgebra.norm(agent.vel)
    direction = Tuple(rotate(SVector(agent.vel), θ, ϕ)) .* relative_r
    agent.vel = direction
    walk!(agent, direction, model)
end

function randomwalk!(
    agent::AbstractAgent,
    model::ABM{<:ContinuousSpace{3}};
    polar=nothing,
    azimuthal=nothing,
)
    if isnothing(polar) && isnothing(azimuthal)
        return uniform_randomwalk!(agent, model)
    end
    θ = rand(abmrng(model), isnothing(polar) ? Uniform(-π,π) : polar)
    ϕ = rand(abmrng(model), isnothing(azimuthal) ? Arccos(-1,1) : azimuthal)
    direction = Tuple(rotate(SVector(agent.vel), θ, ϕ))
    agent.vel = direction
    walk!(agent, direction, model)
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
The resulting vector (`v`) satisfies (v⋅w)/(|v|*|w|) = cos(θ) ∀ ϕ.
"""
function rotate(w::SVector{3}, θ::Real, ϕ::Real)
    # find a vector normal to w
    m = findfirst(w .≠ 0)
    n = m%3 + 1
    u = SVector{3}(0.0, 0.0, 0.0)
    u = setindex(u, w[m], n)
    u = setindex(u, -w[n], m)
    # rotate w around u by the polar angle θ
    a = AngleAxis(θ, u...) * w
    # rotate a around the original vector w by the azimuthal angle ϕ
    AngleAxis(ϕ, w...) * a
end # function

# define new distribution to obtain spherically uniform rotations in 3D
struct Arccos{T<:Real} <: ContinuousUnivariateDistribution
    a::T
    b::T
    Arccos{T}(a::T,b::T) where {T} = new{T}(a::T,b::T)
end
"""
    Arccos(a, b)
Create a `ContinuousUnivariateDistribution` corresponding to `acos(Uniform(a,b))`.
"""
function Arccos(a::Real, b::Real; check_args = true)
    Distributions.@check_args Arccos a<b -1≤a≤1 -1≤b≤1
    return Arccos{Float64}(Float64(a), Float64(b))
end
Arccos() = Arccos(-1,1)
Base.rand(rng::AbstractRNG, d::Arccos) = acos(rand(rng, Uniform(d.a, d.b)))

"""
This is called internally by `randomwalk!` for more performant isotropic/uniform 
random walks; it also works for any number of dimensions.
"""
function uniform_randomwalk!(
    agent::AbstractAgent,
    model::ABM{<:ContinuousSpace{D}},
    r::Real=sqrt(sum(abs2.(agent.vel)))
) where {D}
    if r ≤ 0
        throw(ArgumentError("The displacement must be larger than 0."))
    end
    rng = abmrng(model)
    dim = Val(D)
    v = ntuple(_ -> randn(rng), dim)
    norm_v = sqrt(sum(abs2.(v)))
    if !iszero(norm_v)
        direction = v ./ norm_v .* r
    else
        direction = ntuple(_ -> rand(rng, (-1, 1)) * r / sqrt(D), dim)
    end
    agent.vel = direction
    walk!(agent, direction, model)
end

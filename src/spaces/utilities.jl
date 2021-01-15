export edistance, walk!

#######################################################################################
# %% (Mostly) space agnostic helper functions
#######################################################################################

"""
    edistance(a, b, model::ABM)

Return the euclidean distance between `a` and `b` (either agents or agent positions),
respecting periodic boundary conditions (if in use). Works with any space where it makes
sense: currently `GridSpace` and `ContinuousSpace`.
"""
edistance(
    a::A,
    b::B,
    model::ABM{<:Union{ContinuousSpace,GridSpace}},
) where {A<:AbstractAgent,B<:AbstractAgent} = edistance(a.pos, b.pos, model)

function edistance(
    a::ValidPos,
    b::ValidPos,
    model::ABM{<:Union{ContinuousSpace{D,false},GridSpace{D,false}}},
) where {D}
    sqrt(sum(abs2.(a .- b)))
end

function edistance(
    p1::ValidPos,
    p2::ValidPos,
    model::ABM{<:ContinuousSpace{D,true}},
) where {D}
    total = 0.0
    for (a, b, d) in zip(p1, p2, model.space.extent)
        delta = abs(b - a)
        if delta > d - delta
            delta = d - delta
        end
        total += delta^2
    end
    sqrt(total)
end

function edistance(p1::ValidPos, p2::ValidPos, model::ABM{<:GridSpace{D,true}}) where {D}
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
    walk!(agent, direction::NTuple, model; ifempty = false)

Move agent in the given `direction` respecting periodic boundary conditions.
If `periodic = false`, agents will walk to, but not exceed the boundary value.
Possible on both `GridSpace` and `ContinuousSpace`s.

The dimensionality of `direction` must be the same as the space. `GridSpace` asks for
`Int`, and `ContinuousSpace` for `Float64` vectors, describing the walk distance in
each direction. `direction = (2, -3)` is an example of a valid direction on a
`GridSpace`, which moves the agent to the right 2 positions and down 3 positions.
Velocity is ignored for this opreation in `ContinuousSpace`.

## Keywords
- `ifempty` will check that the target position is unnocupied and only move if that's
true. Available only on `GridSpace`.
"""
function walk!(
    agent::AbstractAgent,
    direction::NTuple{D,Int},
    model::ABM{<:GridSpace{D,true}};
    kwargs...,
) where {D}
    target = mod1.(agent.pos .+ direction, size(model.space))
    walk_if_empty!(agent, target, model; kwargs...)
end

function walk!(
    agent::AbstractAgent,
    direction::NTuple{D,Int},
    model::ABM{<:GridSpace{D,false}};
    kwargs...,
) where {D}
    target = min.(max.(agent.pos .+ direction, 1), size(model.space))
    walk_if_empty!(agent, target, model; kwargs...)
end

function walk!(
    agent::AbstractAgent,
    direction::NTuple{D,Float64},
    model::ABM{<:ContinuousSpace{D,true}};
    kwargs...,
) where {D}
    target = mod1.(agent.pos .+ direction, model.space.extent)
    move_agent!(agent, target, model)
end

function walk!(
    agent::AbstractAgent,
    direction::NTuple{D,Float64},
    model::ABM{<:ContinuousSpace{D,false}};
    kwargs...,
) where {D}
    target = min.(max.(agent.pos .+ direction, 0.0), model.space.extent .- 1e-15)
    move_agent!(agent, target, model)
end

function walk_if_empty!(agent, target, model; ifempty::Bool = false)
    if ifempty
        isempty(target, model) && move_agent!(agent, target, model)
    else
        move_agent!(agent, target, model)
    end
end

"""
    walk!(agent, rand, model)

Invoke a random walk by providing the `rand` function in place of
`distance`. For `GridSpace`, the walk will cover ±1 positions in all directions,
`ContinuousSpace` will reside within [-1, 1].
"""
walk!(agent, ::typeof(rand), model::ABM{<:GridSpace{D}}; kwargs...) where {D} =
    walk!(agent, Tuple(rand(-1:1) for _ in 1:D), model; kwargs...)

walk!(agent, ::typeof(rand), model::ABM{<:ContinuousSpace{D}}; kwargs...) where {D} =
    walk!(agent, Tuple(2.0 * rand() - 1.0 for _ in 1:D), model; kwargs...)

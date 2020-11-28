export edistance,
    walk!, North, South, East, West, NorthEast, NorthWest, SouthEast, SouthWest

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
    model::ABM{C,<:Union{ContinuousSpace,GridSpace}},
) where {A<:AbstractAgent,B<:AbstractAgent,C} = edistance(a.pos, b.pos, model)

function edistance(
    a::ValidPos,
    b::ValidPos,
    model::ABM{A,<:Union{ContinuousSpace{D,false},GridSpace{D,false}}},
) where {A,D}
    sqrt(sum(abs2.(a .- b)))
end

function edistance(
    p1::ValidPos,
    p2::ValidPos,
    model::ABM{A,<:ContinuousSpace{D,true}},
) where {A,D}
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

function edistance(
    p1::ValidPos,
    p2::ValidPos,
    model::ABM{A,<:GridSpace{D,true}},
) where {A,D}
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

abstract type Direction end
struct North <: Direction end
struct South <: Direction end
struct East <: Direction end
struct West <: Direction end
struct NorthWest <: Direction end
struct SouthWest <: Direction end
struct NorthEast <: Direction end
struct SouthEast <: Direction end

unitvector(d::Type{North}) = (0, 1)
unitvector(d::Type{South}) = (0, -1)
unitvector(d::Type{East}) = (1, 0)
unitvector(d::Type{West}) = (-1, 0)
unitvector(d::Type{NorthEast}) = (1, 1)
unitvector(d::Type{NorthWest}) = (-1, 1)
unitvector(d::Type{SouthEast}) = (1, -1)
unitvector(d::Type{SouthWest}) = (-1, -1)

"""
    walk!(agent, direction, model, distance=1)

Move agent in the given `direction` one grid position (by default). Only possible on a 2D
`GridSpace`, respects periodic boundary conditions. If `periodic = false`, agents will
walk to, but not exceed the boundary value.

Possible directions are `North`, `South`, `East`, `West`, as well as `NorthEast`,
`SouthEast`, `SouthWest` and `NorthWest`.
"""

# Periodic
function walk!(
    agent::AbstractAgent,
    direction::Type{<:Direction},
    model::ABM{<:AbstractAgent,<:GridSpace{2,true}},
    distance::Int = 1,
)
    (h, v) = unitvector(direction) .* distance
    agent.pos = (
        mod1(agent.pos[1] + h, size(model.space)[1]),
        mod1(agent.pos[2] + v, size(model.space)[2]),
    )
end

# Non-Periodic
function walk!(
    agent::AbstractAgent,
    direction::Type{<:Direction},
    model::ABM{<:AbstractAgent,<:GridSpace{2,false}},
    distance::Int = 1,
)
    (h, v) = unitvector(direction) .* distance
    agent.pos = (
        min(max(agent.pos[1] + h, 1), size(model.space)[1]),
        min(max(agent.pos[2] + v, 1), size(model.space)[2]),
    )
end

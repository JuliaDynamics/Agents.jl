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
    direction::Type{East},
    model::ABM{<:AbstractAgent,<:GridSpace{2,true}},
    distance::Int = 1,
)
    agent.pos = (mod1(agent.pos[1] + distance, size(model.space)[1]), agent.pos[2])
end

function walk!(
    agent::AbstractAgent,
    direction::Type{West},
    model::ABM{<:AbstractAgent,<:GridSpace{2,true}},
    distance::Int = 1,
)
    agent.pos = (mod1(agent.pos[1] - distance, size(model.space)[1]), agent.pos[2])
end

function walk!(
    agent::AbstractAgent,
    direction::Type{North},
    model::ABM{<:AbstractAgent,<:GridSpace{2,true}},
    distance::Int = 1,
)
    agent.pos = (agent.pos[1], mod1(agent.pos[2] + distance, size(model.space)[2]))
end

function walk!(
    agent::AbstractAgent,
    direction::Type{South},
    model::ABM{<:AbstractAgent,<:GridSpace{2,true}},
    distance::Int = 1,
)
    agent.pos = (agent.pos[1], mod1(agent.pos[2] - distance, size(model.space)[2]))
end

function walk!(
    agent::AbstractAgent,
    direction::Type{NorthEast},
    model::ABM{<:AbstractAgent,<:GridSpace{2,true}},
    distance::Int = 1,
)
    agent.pos = (
        mod1(agent.pos[1] + distance, size(model.space)[1]),
        mod1(agent.pos[2] + distance, size(model.space)[2]),
    )
end

function walk!(
    agent::AbstractAgent,
    direction::Type{NorthWest},
    model::ABM{<:AbstractAgent,<:GridSpace{2,true}},
    distance::Int = 1,
)
    agent.pos = (
        mod1(agent.pos[1] - distance, size(model.space)[1]),
        mod1(agent.pos[2] + distance, size(model.space)[2]),
    )
end

function walk!(
    agent::AbstractAgent,
    direction::Type{SouthEast},
    model::ABM{<:AbstractAgent,<:GridSpace{2,true}},
    distance::Int = 1,
)
    agent.pos = (
        mod1(agent.pos[1] + distance, size(model.space)[1]),
        mod1(agent.pos[2] - distance, size(model.space)[2]),
    )
end

function walk!(
    agent::AbstractAgent,
    direction::Type{SouthWest},
    model::ABM{<:AbstractAgent,<:GridSpace{2,true}},
    distance::Int = 1,
)
    agent.pos = (
        mod1(agent.pos[1] - distance, size(model.space)[1]),
        mod1(agent.pos[2] - distance, size(model.space)[2]),
    )
end

# Non-Periodic
function walk!(
    agent::AbstractAgent,
    direction::Type{East},
    model::ABM{<:AbstractAgent,<:GridSpace{2,false}},
    distance::Int = 1,
)
    step = min(agent.pos[1] + distance, size(model.space)[1])
    agent.pos = (step, agent.pos[2])
end

function walk!(
    agent::AbstractAgent,
    direction::Type{West},
    model::ABM{<:AbstractAgent,<:GridSpace{2,false}},
    distance::Int = 1,
)

    step = max(agent.pos[1] - distance, 1)
    agent.pos = (step, agent.pos[2])
end

function walk!(
    agent::AbstractAgent,
    direction::Type{North},
    model::ABM{<:AbstractAgent,<:GridSpace{2,false}},
    distance::Int = 1,
)
    step = min(agent.pos[2] + distance, size(model.space)[2])
    agent.pos = (agent.pos[1], step)
end

function walk!(
    agent::AbstractAgent,
    direction::Type{South},
    model::ABM{<:AbstractAgent,<:GridSpace{2,false}},
    distance::Int = 1,
)
    step = max(agent.pos[2] - distance, 1)
    agent.pos = (agent.pos[1], step)
end

function walk!(
    agent::AbstractAgent,
    direction::Type{NorthEast},
    model::ABM{<:AbstractAgent,<:GridSpace{2,false}},
    distance::Int = 1,
)
    horiz = min(agent.pos[1] + distance, size(model.space)[1])
    vert = min(agent.pos[2] + distance, size(model.space)[2])
    agent.pos = (horiz, vert)
end

function walk!(
    agent::AbstractAgent,
    direction::Type{NorthWest},
    model::ABM{<:AbstractAgent,<:GridSpace{2,false}},
    distance::Int = 1,
)
    horiz = max(agent.pos[1] - distance, 1)
    vert = min(agent.pos[2] + distance, size(model.space)[2])
    agent.pos = (horiz, vert)
end

function walk!(
    agent::AbstractAgent,
    direction::Type{SouthEast},
    model::ABM{<:AbstractAgent,<:GridSpace{2,false}},
    distance::Int = 1,
)
    horiz = min(agent.pos[1] + distance, size(model.space)[1])
    vert = max(agent.pos[2] - distance, 1)
    agent.pos = (horiz, vert)
end

function walk!(
    agent::AbstractAgent,
    direction::Type{SouthWest},
    model::ABM{<:AbstractAgent,<:GridSpace{2,false}},
    distance::Int = 1,
)
    horiz = max(agent.pos[1] - distance, 1)
    vert = max(agent.pos[2] - distance, 1)
    agent.pos = (horiz, vert)
end

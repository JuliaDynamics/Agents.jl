export euclidean

#######################################################################################
# %% (Mostly) space agnostic helper functions
#######################################################################################

"""
    euclidean(a, b, model::ABM)

Return the euclidean distance between `a` and `b` (either agents or agent positions),
respecting periodic boundary conditions (if in use). Works with any space where it makes
sense: currently `GridSpace` and `ContinuousSpace`.
"""
euclidean(
    a::A,
    b::B,
    model::ABM{C,<:Union{ContinuousSpace,GridSpace}},
) where {A<:AbstractAgent,B<:AbstractAgent,C} = euclidean(a.pos, b.pos, model)

function euclidean(
    a::ValidPos,
    b::ValidPos,
    model::ABM{A,<:Union{ContinuousSpace{D,false},GridSpace{D,false}}},
) where {A,D}
    sqrt(sum(abs2.(a .- b)))
end

function euclidean(
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

function euclidean(p1::ValidPos, p2::ValidPos, model::ABM{A,<:GridSpace{D,true}}) where {A,D}
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


export edistance

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

function edistance(p1::ValidPos, p2::ValidPos, model::ABM{A,<:GridSpace{D,true}}) where {A,D}
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
    nv(model::ABM)
Return the number of positions (vertices) in the `model` space.
"""
LightGraphs.nv(abm::ABM{<:Any,<:Union{GraphSpace, OpenStreetMapSpace}}) = LightGraphs.nv(abm.space.graph)
LightGraphs.nv(space::S) where {S<:Union{GraphSpace,OpenStreetMapSpace}} = LightGraphs.nv(space.graph)

"""
    ne(model::ABM)
Return the number of edges in the `model` space.
"""
LightGraphs.ne(abm::ABM{<:Any,<:Union{GraphSpace, OpenStreetMapSpace}}) = LightGraphs.ne(abm.space.graph)


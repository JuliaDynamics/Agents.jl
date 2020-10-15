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
LightGraphs.nv(abm::ABM{A,<:Union{GraphSpace, OpenStreetMapSpace}}) where {A} = LightGraphs.nv(abm.space)
LightGraphs.nv(space::S) where {S<:GraphSpace} = LightGraphs.nv(space.graph)
LightGraphs.nv(space::S) where {S<:OpenStreetMapSpace} = LightGraphs.nv(space.m.g)

"""
    ne(model::ABM)
Return the number of edges in the `model` space.
"""
LightGraphs.ne(abm::ABM{A,<:Union{GraphSpace, OpenStreetMapSpace}}) where {A} = LightGraphs.ne(abm.space)
LightGraphs.ne(space::S) where {S<:GraphSpace} = LightGraphs.ne(space.graph)
LightGraphs.ne(space::S) where {S<:OpenStreetMapSpace} = LightGraphs.ne(space.m.g)


positions(model::ABM{<:AbstractAgent,<:Union{GraphSpace, OpenStreetMapSpace}}) = 1:nv(model)

function nearby_positions(
        position::Integer,
        model::ABM{A,<:Union{GraphSpace,OpenStreetMapSpace}},
        radius::Integer;
        kwargs...,
    ) where {A}
    output = copy(nearby_positions(position, model; kwargs...))
    for _ in 2:radius
        newnps = (nearby_positions(np, model; kwargs...) for np in output)
        append!(output, reduce(vcat, newnps))
        unique!(output)
    end
    filter!(i -> i != position, output)
end

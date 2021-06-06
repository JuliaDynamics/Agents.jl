using JLD2

struct SerializedABM{S<:SpaceType,A<:AbstractAgent,P,R<:AbstractRNG}
    agents::Vector{A}
    space::S
    properties::P
    rng::R
    maxid::Int64
end

JLD2.writeas(::Type{ABM{S,A,F,P,R}}) where {S,A,F,P,R} = SerializedABM{S,A,P,R}

JLD2.wconvert(::Type{SerializedABM{S,A,P,R}}, abm::ABM{S,A,F,P,R}) where {S,A,F,P,R} =
    SerializedABM{S,A,P,R}(
        collect(values(abm.agents)),
        abm.space,
        abm.properties,
        abm.rng,
        abm.maxid.x,
    )

function JLD2.rconvert(::Type{ABM{S,A,F,P,R}}, sabm::SerializedABM{S,A,P,R}) where {S,A,F,P,R}
    abm = ABM{S,A,F,P,R}(
        Dict(a.id => a for a in sabm.agents),
        sabm.space,
        Schedulers.fastest,
        sabm.properties,
        sabm.rng,
        Base.RefValue{Int64}(sa.maxid),
    )

    for a in sabm.agents
        push!(abm.space.s[a, pos...], a.id)
    end
end

struct SerializedGridSpace{D,P,W}
    s::Array{Vector{Int},D}
    metric::Symbol
    hoods::Vector{Tuple{Float64,Hood{D}}}
    hoods_tuple::Vector{Tuple{NTuple{D,Float64},Hood{D}}}
    pathfinder::W
end

JLD2.writeas(::Type{GridSpace{D,P,W}}) = SerializedGridSpace{D,P,W}

JLD2.wconvert(::Type{SerializedGridSpace{D,P,W}}, sp::GridSpace{D,P,W}) where {D,P,W} =
    SerializedGridSpace{D,P,W}(
        sp.s,
        sp.metric,
        [(k, v) for (k, v) in sp.hoods],
        [(k, v) for (k, v) in sp.hoods_tuple],
        sp.pathfinder,
    )

JLD2.rconvert(::Type{GridSpace{D,P,W}}, sp::SerializedGridSpace{D,P,W}) where {D,P,W} =
    GridSpace{D,P,W}(
        sp.s,
        sp.metric,
        Dict(k => v for (k, v) in sp.hoods),
        Dict(k => v for (k, v) in sp.hoods_tuple),
        sp.pathfinder,
    )

struct SerializedContinuousSpace{D,P,T<:AbstractFloat}
    grid::GridSpace{D,P}
    dims::NTuple{D,Int}
    spacing::T
    extent::NTuple{D,T}
end

JLD2.writeas(::Type{ContinuousSpace{D,P,T}}) where {D,P,T} = SerializedContinuousSpace{D,P,T}

JLD2.wconvert(
    ::Type{SerializedContinuousSpace{D,P,T}},
    sp::ContinuousSpace{D,P,T},
) where {D,P,T} = SerializedContinuousSpace{D,P,T}(sp.grid, sp.dims, sp.spacing, sp.extent)

JLD2.rconvert(
    ::Type{ContinuousSpace{D,P,T,F}},
    sp::SerializedContinuousSpace{D,P,T},
) where {D,P,T,F} = ContinuousSpace{D,P,T,F}(sp.grid, defvel, sp.dims, sp.spacing, sp.extent)

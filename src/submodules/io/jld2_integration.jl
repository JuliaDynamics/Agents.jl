using Random
using JLD2

to_serializable(t; kwargs...) = t
from_serializable(t; kwargs...) = t

struct SerializableABM{S,A<:AbstractAgent,P,R<:AbstractRNG}
    agents::Vector{A}
    space::S
    properties::P
    rng::R
    maxid::Int64
end

struct SerializableGridSpace{D,P,W}
    dims::NTuple{D,Int}
    metric::Symbol
    hoods::Vector{Tuple{Float64,Agents.Hood{D}}}
    hoods_tuple::Vector{Tuple{NTuple{D,Float64},Agents.Hood{D}}}
    pathfinder::W
end

struct SerializableContinuousSpace{D,P,T<:AbstractFloat}
    grid::SerializableGridSpace{D,P}
    dims::NTuple{D,Int}
    spacing::T
    extent::NTuple{D,T}
end

struct SerializableGraphSpace{G}
    graph::G
end

struct SerializableAStar{D,P,M}
    agent_paths::Vector{Tuple{Int,Vector{Dims{D}}}}
    grid_dims::Dims{D}
    neighborhood::Vector{Dims{D}}
    admissibility::Float64
    walkable::BitArray{D}
    cost_metric::Pathfinding.CostMetric{D}
end

to_serializable(t::ABM; kwargs...) = SerializableABM(
    collect(values(t.agents)),
    to_serializable(t.space; kwargs...),
    t.properties,
    t.rng,
    t.maxid.x,
)

to_serializable(t::GridSpace{D,P,W}; kwargs...) where {D,P,W} = SerializableGridSpace{D,P,W}(
    size(t.s),
    t.metric,
    [(k, v) for (k, v) in t.hoods],
    [(k, v) for (k, v) in t.hoods_tuple],
    to_serializable(t.pathfinder; kwargs...),
)

to_serializable(t::ContinuousSpace{D,P,T}; kwargs...) where {D,P,T} =
    SerializableContinuousSpace{D,P,T}(
        to_serializable(t.grid; kwargs...),
        t.dims,
        t.spacing,
        t.extent,
    )

to_serializable(t::GraphSpace{G}; kwargs...) where {G} = SerializableGraphSpace{G}(t.graph)

to_serializable(t::Pathfinding.AStar{D,P,M}; kwargs...) where {D,P,M} =
    SerializableAStar{D,P,M}(
        [(k, collect(v)) for (k, v) in t.agent_paths],
        t.grid_dims,
        map(Tuple, t.neighborhood),
        t.admissibility,
        t.walkable,
        t.cost_metric,
    )

function from_serializable(t::SerializableABM{S,A}; kwargs...) where {S,A}
    abm = ABM(
        A,
        from_serializable(t.space; kwargs...);
        scheduler = get(kwargs, :scheduler, Schedulers.fastest),
        properties = t.properties,
        rng = t.rng,
    )
    abm.maxid[] = t.maxid
    for a in t.agents
        add_agent_pos!(a, abm)
    end
    return abm
end

function from_serializable(t::SerializableGridSpace{D,P,W}; kwargs...) where {D,P,W}
    s = Array{Vector{Int},D}(undef, t.dims)
    for i in eachindex(s)
        s[i] = Int[]
    end
    return GridSpace{D,P,W}(
        s,
        t.metric,
        Dict(k => v for (k, v) in t.hoods),
        Dict(k => v for (k, v) in t.hoods_tuple),
        from_serializable(t.pathfinder; kwargs...),
    )
end

function from_serializable(t::SerializableContinuousSpace{D,P,T}; kwargs...) where {D,P,T}
    update_vel! = get(kwargs, :update_vel!, Agents.defvel)
    ContinuousSpace(
        from_serializable(t.grid; kwargs...),
        update_vel!,
        t.dims,
        t.spacing,
        t.extent,
    )
end

from_serializable(t::SerializableGraphSpace; kwargs...) = GraphSpace(t.graph)

from_serializable(t::SerializableAStar{D,P,M}; kwargs...) where {D,P,M} =
    Pathfinding.AStar{D,P,M}(
        Dict{Int,Pathfinding.Path{D}}(
            k => Pathfinding.Path{D}(v...) for (k, v) in t.agent_paths
        ),
        t.grid_dims,
        map(CartesianIndex, t.neighborhood),
        t.admissibility,
        t.walkable,
        t.cost_metric,
    )

function dump_to_jld2(filename, model::ABM; kwargs...)
    if model.space isa OpenStreetMapSpace
        @info "The underlying OpenStreetMap in OpenStreetMapSpace is not saved."
    end
    model = to_serializable(model; kwargs...)
    @save filename model
end

function load_from_jld2(filename; kwargs...)
    @load filename model
    return from_serializable(model; kwargs...)
end

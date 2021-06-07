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
    to_serializable(t.pathfinder),
)

to_serializable(t::ContinuousSpace{D,P,T}; kwargs...) where {D,P,T} =
    SerializableContinuousSpace{D,P,T}(
        to_serializable(t.grid; kwargs...),
        t.dims,
        t.spacing,
        t.extent,
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
    ContinuousSpace{D,P,T,eltype(update_vel!)}(
        from_serializable(t.grid),
        update_vel!,
        t.dims,
        t.spacing,
        t.extent,
    )
end

function dump_to_jld2(filename, model::ABM; kwargs...)
    if model.space isa GraphSpace
        @info "The underlying graph in GraphSpace is not saved. Use GraphIO.jl to save the graph as a separate file"
    end
    if model.space isa OpenStreetMapSpace
        @info "The underlying OpenStreetMap in OpenStreetMapSpace is not saved."
    end
    model = to_serializable(model)
    @save filename model
end

function load_from_jld2(filename; kwargs...)
    @load filename model
    return from_serializable(model)
end

using Random
using JLD2

"""
    AgentsIO.to_serializable(t)

Return the serializable form of the passed value. This defaults to the value itself,
unless a more specific method is defined. Define a method for this function and for
[`AgentsIO.from_serializable`](@ref) if you need custom serialization for model
properties. This also enables passing keyword arguments to [`AgentsIO.load_checkpoint`](@ref)
and having access to them during deserialization of the properties. Some possible
scenarios where this may be required are:

- Your properties contain functions (or any type not supported by JLD2.jl). These may not
  be (de)serialized correctly. This could result in checkpoint files that cannot be loaded
  back in, or contain reconstructed types that do not retain their data/functionality.
- Your properties contain data that can be recalculated during deserialization. Omitting
  such properties can reduce the size of the checkpoint file, at the expense of some extra
  computation at deserialization.

If your model properties do not fall in the above scenarios, you do not need to use this
function.

This function is not called recursively on every type/value during serialization. The final
serialization functionality is enabled by JLD2.jl. To define custom serialization
for every occurence of a specific type (such as agent structs), refer to the
Custom Serialization section of JLD2.jl documentation.
"""
to_serializable(t) = t

"""
    AgentsIO.from_serializable(t; kwargs...)

Given a value in its serializable form, return the original version. This defaults
to the value itself, unless a more specific method is defined. Define a method for 
this function and for [`AgentsIO.to_serializable`](@ref) if you need custom
serialization for model properties. This also enables passing keyword arguments
to [`AgentsIO.load_checkpoint`](@ref) and having access to them through `kwargs`.

Refer to [`AgentsIO.to_serializable`](@ref) to check when you need to define this function.

This function is not called recursively on every type/value during deserialization. The final
serialization functionality is enabled by JLD2.jl. To define custom serialization
for every occurence of a specific type (such as agent structs), refer to the
Custom Serialization section of JLD2.jl documentation.
"""
from_serializable(t; kwargs...) = t

struct SerializableABM{S,A<:AbstractAgent,P,R<:AbstractRNG}
    agents::Vector{A}
    space::S
    properties::P
    rng::R
    maxid::Int64
end

struct SerializableGridSpace{D,P}
    dims::NTuple{D,Int}
    metric::Symbol
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

struct OSMAgentPositionData
    id::Int
    pos::Tuple{NTuple{2,Float64},NTuple{2,Float64},Float64}
    dest::Tuple{NTuple{2,Float64},NTuple{2,Float64},Float64}
    route::Vector{NTuple{2,Float64}}
end

struct SerializableOSMSpace
    agents::Vector{OSMAgentPositionData}
end

struct SerializableAStar{D,P,M}
    agent_paths::Vector{Tuple{Int,Vector{Dims{D}}}}
    grid_dims::Dims{D}
    neighborhood::Vector{Dims{D}}
    admissibility::Float64
    walkable::BitArray{D}
    cost_metric::Pathfinding.CostMetric{D}
end

JLD2.writeas(::Type{Pathfinding.AStar{D,P,M}}) where {D,P,M} = SerializableAStar{D,P,M}

function to_serializable(t::ABM{S}) where {S}
    sabm = SerializableABM(
        collect(allagents(t)),
        to_serializable(t.space),
        to_serializable(t.properties),
        t.rng,
        t.maxid.x,
    )
    if S <: OSM.OpenStreetMapSpace
        for i in 1:nagents(t)
            sabm.agents[i] = typeof(sabm.agents[i])(
                (
                    getproperty(sabm.agents[i], x) for x in fieldnames(typeof(sabm.agents[i]))
                )...,
            )
            sabm.agents[i].route = []
        end

        for a in allagents(t)
            push!(
                sabm.space.agents,
                OSMAgentPositionData(
                    a.id,
                    (OSM.latlon(a.pos[1], t), OSM.latlon(a.pos[2], t), a.pos[3]),
                    (
                        OSM.latlon(a.destination[1], t),
                        OSM.latlon(a.destination[2], t),
                        a.destination[3],
                    ),
                    [OSM.latlon(i, t) for i in a.route],
                ),
            )
        end
    end
    return sabm
end

to_serializable(t::GridSpace{D,P}) where {D,P} =
    SerializableGridSpace{D,P}(size(t.s), t.metric)

to_serializable(t::ContinuousSpace{D,P,T}) where {D,P,T} =
    SerializableContinuousSpace{D,P,T}(to_serializable(t.grid), t.dims, t.spacing, t.extent)

to_serializable(t::GraphSpace{G}) where {G} = SerializableGraphSpace{G}(t.graph)

to_serializable(t::OSM.OpenStreetMapSpace) = SerializableOSMSpace([])

JLD2.wconvert(::Type{SerializableAStar{D,P,M}}, t::Pathfinding.AStar{D,P,M}) where {D,P,M} =
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
        properties = from_serializable(t.properties; kwargs...),
        rng = t.rng,
        warn = get(kwargs, :warn, true),
    )
    abm.maxid[] = t.maxid

    if S <: SerializableOSMSpace
        agentdata = Dict(a.id => a for a in t.space.agents)
        for a in t.agents
            a.pos = (
                OSM.intersection(agentdata[a.id].pos[1], abm)[1],
                OSM.intersection(agentdata[a.id].pos[2], abm)[1],
                agentdata[a.id].pos[3],
            )
            a.destination = (
                OSM.intersection(agentdata[a.id].dest[1], abm)[1],
                OSM.intersection(agentdata[a.id].dest[2], abm)[1],
                agentdata[a.id].dest[3],
            )
            a.route = [OSM.intersection(i, abm)[1] for i in agentdata[a.id].route]
        end
    end

    for a in t.agents
        add_agent_pos!(a, abm)
    end
    return abm
end

function from_serializable(t::SerializableGridSpace{D,P}; kwargs...) where {D,P}
    s = Array{Vector{Int},D}(undef, t.dims)
    for i in eachindex(s)
        s[i] = Int[]
    end
    return GridSpace{D,P}(s, t.metric, Dict(), Dict())
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

function from_serializable(t::SerializableOSMSpace; kwargs...)
    @assert haskey(kwargs, :map) "Path to OpenStreetMap not provided"

    OSM.OpenStreetMapSpace(
        get(kwargs, :map, OSM.TEST_MAP);   # Should never need default value
        use_cache = get(kwargs, :use_cache, false),
        trim_to_connected_graph = get(kwargs, :trim_to_connected_graph, true),
    )
end

JLD2.rconvert(::Pathfinding.AStar{D,P,M}, t::SerializableAStar{D,P,M}) where {D,P,M} =
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

"""
    AgentsIO.save_checkpoint(filename, model::ABM)

Write the entire `model` to file specified by `filename`. The following points
should be considered before using this functionality:

- OpenStreetMap data is not saved. The path to the map should be specified when loading
  the model using the `map` keyword of [`AgentsIO.load_checkpoint`](@ref).
- Functions are not saved, including stepping functions, schedulers, and `update_vel!`.
  The last two can be provided to [`AgentsIO.load_checkpoint`](@ref) using the appropriate
  keyword arguments.
"""
function save_checkpoint(filename, model::ABM)
    model = to_serializable(model)
    @save filename model
end

"""
    AgentsIO.load_checkpoint(filename; kwargs...)

Load the model saved to the file specified by `filename`.

## Keywords
- `scheduler = Schedulers.fastest` specifies what scheduler should
  be used for the model.
- `warn = true` can be used to disable warnings from type checks on the
    agent type.
[`ContinuousSpace`](@ref) specific:
- `update_vel!` specifies a function that should be used to
  update each agent's velocity before it is moved. Refer to [`ContinuousSpace`](@ref) for
  details.
[`OpenStreetMapSpace`](@ref) specific:
- `map` is a path to the OpenStreetMap to be used for the space. This is a required parameter
  if the space is [`OpenStreetMapSpace`](@ref).
- `use_cache = false`, `trim_to_connected_graph = true` refer to [`OpenStreetMapSpace`](@ref)
"""
function load_checkpoint(filename; kwargs...)
    @load filename model
    return from_serializable(model; kwargs...)
end

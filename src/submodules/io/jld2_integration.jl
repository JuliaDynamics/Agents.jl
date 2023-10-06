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

This function, and [`AgentsIO.from_serializable`](@ref)
is not called recursively on every type/value during serialization. The final
serialization functionality is enabled by JLD2.jl. To define custom serialization
for every occurrence of a specific type (such as agent structs), refer to the
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

Refer to [`AgentsIO.to_serializable`](@ref) for more info.
"""
from_serializable(t; kwargs...) = t

struct SerializableABM{S,A<:AbstractAgent,C,P,R<:AbstractRNG}
    agents::Vector{A}
    space::S
    agents_container::C
    properties::P
    rng::R
    maxid::Int64
end

struct SerializableGridSpace{D,P}
    dims::NTuple{D,Int}
    metric::Symbol
end
struct SerializableGridSpaceSingle{D,P}
    dims::NTuple{D,Int}
    metric::Symbol
end

struct SerializableContinuousSpace{D,P,T<:AbstractFloat}
    grid::SerializableGridSpace{D,P}
    dims::NTuple{D,Int}
    spacing::T
    extent::SVector{D,T}
end

struct SerializableGraphSpace{G}
    graph::G
end
struct SerializableOSMSpace
    routes::Vector{Tuple{Int,OSM.OpenStreetMapPath}}
end

struct SerializableAStar{D,P,M,T,C}
    agent_paths::Vector{Tuple{Int,Vector{NTuple{D,T}}}}
    dims::NTuple{D,T}
    neighborhood::Vector{Dims{D}}
    admissibility::Float64
    walkmap::BitArray{D}
    cost_metric::C
end

JLD2.writeas(::Type{Pathfinding.AStar{D,P,M,T,C}}) where {D,P,M,T,C} = SerializableAStar{D,P,M,T,C}

function to_serializable(t::ABM{S}) where {S}
    sabm = SerializableABM(
        collect(allagents(t)),
        to_serializable(abmspace(t)),
        typeof(agent_container(t)),
        to_serializable(abmproperties(t)),
        abmrng(t),
        getfield(t, :maxid).x,
    )
    return sabm
end

to_serializable(t::GridSpace{D,P}) where {D,P} =
    SerializableGridSpace{D,P}(spacesize(t), t.metric)
to_serializable(t::GridSpaceSingle{D,P}) where {D,P} =
    SerializableGridSpaceSingle{D,P}(spacesize(t), t.metric)

to_serializable(t::ContinuousSpace{D,P,T}) where {D,P,T} =
    SerializableContinuousSpace{D,P,T}(to_serializable(t.grid), t.dims, t.spacing, t.extent)

to_serializable(t::GraphSpace{G}) where {G} = SerializableGraphSpace{G}(t.graph)

to_serializable(t::OSM.OpenStreetMapSpace) = SerializableOSMSpace([(k, v) for (k, v) in t.routes])

JLD2.wconvert(::Type{SerializableAStar{D,P,M,T,C}}, t::Pathfinding.AStar{D,P,M,T,C}) where {D,P,M,T,C} =
    SerializableAStar{D,P,M,T,C}(
        [(k, collect(v)) for (k, v) in t.agent_paths],
        t.dims,
        map(Tuple, t.neighborhood),
        t.admissibility,
        t.walkmap,
        t.cost_metric,
    )

function from_serializable(t::SerializableABM{S,A}; kwargs...) where {S,A}
    abm = StandardABM(
        A,
        from_serializable(t.space; kwargs...),
        container = t.agents_container,
        scheduler = get(kwargs, :scheduler, Schedulers.fastest),
        properties = from_serializable(t.properties; kwargs...),
        rng = t.rng,
        warn = get(kwargs, :warn, true),
        warn_deprecation = false
    )
    getfield(abm, :maxid)[] = t.maxid

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
    return GridSpace{D,P}(s, t.dims, t.metric, Vector(), Vector(), Vector(), Dict())
end
function from_serializable(t::SerializableGridSpaceSingle{D,P}; kwargs...) where {D,P}
    s = zeros(Int, t.dims)
    return GridSpaceSingle{D,P}(s, t.dims, t.metric, Vector(), Vector(), Vector())
end

function from_serializable(t::SerializableContinuousSpace{D,P,T}; kwargs...) where {D,P,T}
    update_vel! = get(kwargs, :update_vel!, Agents.no_vel_update)
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

    space = OSM.OpenStreetMapSpace(
        get(kwargs, :map, OSM.test_map());   # Should never need default value
    )
    for (k, v) in t.routes
        space.routes[k] = v
    end
    return space
end

JLD2.rconvert(::Type{Pathfinding.AStar{D,P,M,T,C}}, t::SerializableAStar{D,P,M,T,C}) where {D,P,M,T,C} =
    Pathfinding.AStar{D,P,M,T,C}(
        Dict{Int,Pathfinding.Path{D,T}}(
            k => Pathfinding.Path{D,T}(v...) for (k, v) in t.agent_paths
        ),
        t.dims,
        map(CartesianIndex, t.neighborhood),
        t.admissibility,
        t.walkmap,
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

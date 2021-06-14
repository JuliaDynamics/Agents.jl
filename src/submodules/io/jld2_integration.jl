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

struct SerializableGridSpace{D,P,W}
    dims::NTuple{D,Int}
    metric::Symbol
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

to_serializable(t::ABM) = SerializableABM(
    collect(values(t.agents)),
    to_serializable(t.space),
    to_serializable(t.properties),
    t.rng,
    t.maxid.x,
)

function to_serializable(t::GridSpace{D,P,W}) where {D,P,W}
    pathfinder = to_serializable(t.pathfinder)
    SerializableGridSpace{D,P,typeof(pathfinder)}(
        size(t.s),
        t.metric,
        pathfinder,
    )
end

to_serializable(t::ContinuousSpace{D,P,T}) where {D,P,T} =
    SerializableContinuousSpace{D,P,T}(
        to_serializable(t.grid),
        t.dims,
        t.spacing,
        t.extent,
    )

to_serializable(t::GraphSpace{G}) where {G} = SerializableGraphSpace{G}(t.graph)

to_serializable(t::Pathfinding.AStar{D,P,M}) where {D,P,M} =
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
    pathfinder = from_serializable(t.pathfinder; kwargs...)
    return GridSpace{D,P,typeof(pathfinder)}(
        s,
        t.metric,
        Dict(),
        Dict(),
        pathfinder,
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

"""
    AgentsIO.save_checkpoint(filename, model::ABM)

Write the entire `model` to file specified by `filename`. The following points
should be considered before using this functionality:

- Currently, serialization is also not supported for models using OpenStreetMapSpace.
- Functions are not saved, including stepping functions, schedulers, and `update_vel!`.
  The last two can be provided to [`AgentsIO.load_checkpoint`](@ref) using the appropriate
  keyword arguments.
"""
function save_checkpoint(filename, model::ABM)
    @assert !(model.space isa OpenStreetMapSpace) "Currently serialization is not supported for OpenStreetMapSpace"
    model = to_serializable(model)
    @save filename model
end

"""
    AgentsIO.load_checkpoint(filename; kwargs...)

Load the model saved to the file specified by `filename`.

The keyword argument `scheduler = Schedulers.fastest` specifies what scheduler should
be used for the model.

The keyword argument `update_vel!` specifies a function that should be used to
update each agent's velocity before it is moved. Refer to [`ContinuousSpace`](@ref) for
details.

The keyword argument `warn = true` can be used to disable warnings from type checks on the
agent type.

Any other keyword arguments are forwarded to [`AgentsIO.from_serializable`](@ref) and
can be used in case a custom method is defined.
"""
function load_checkpoint(filename; kwargs...)
    @load filename model
    return from_serializable(model; kwargs...)
end

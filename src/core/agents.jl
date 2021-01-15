export AbstractAgent, @agent, GraphAgent, GridAgent, ContinuousAgent

"""
    AbstractAgent
All agents must be a mutable subtype of `AbstractAgent`.
Your agent type **must have** the `id` field as first field.
Depending on the space structure there might be a `pos` field of appropriate type
and a `vel` field of appropriate type.
Each space structure quantifies precicely what extra fields (if any) are necessary,
however we recommend to use the [`@agent`] macro to help you create the agent type.

Your agent type may have other additional fields relevant to your system,
for example variable quantities like "status" or other "counters".

## Examples
As an example, a [`GraphSpace`](@ref) requires an `id::Int` field and a `pos::Int` field.
To make an agent with two additional properties, `weight, happy`, we'd write
```julia
mutable struct ExampleAgent <: AbstractAgent
    id::Int
    pos::Int
    weight::Float64
    happy::Bool
end
```
"""
abstract type AbstractAgent end

"""
    @agent YourAgentType{X, Y} AgentSupertype begin
        some_property::X
        other_extra_property::Y
        # etc...
    end

Create a struct for your agents which includes the mandatory fields required to operate
in a particular space. Depending on the space of your model, the `AgentSupertype` is
chosen appropriately from [`GraphAgent`](@ref), [`GridAgent`](@ref),
[`ContinuousAgent`](@ref).

## Example
Using
```julia
@agent Person{T} GridAgent{2} begin
    age::Int
    moneyz::T
end
```
will in fact create an agent appropriate for using with 2-dimensional [`GridSpace`](@ref)
```julia
mutable struct Person{T} <: AbstractAgent
    id::Int
    pos::NTuple{2, Int}
    age::Int
    moneyz::T
end
```
"""
macro agent(name, base, fields)
    base_type = Core.eval(@__MODULE__, base)
    base_fieldnames = fieldnames(base_type)
    base_types = [t for t in base_type.types]
    base_fields = [:($f::$T) for (f, T) in zip(base_fieldnames, base_types)]
    res = :(mutable struct $name <: AbstractAgent end)
    push!(res.args[end].args, base_fields...)
    push!(res.args[end].args, fields.args...)
    return res
end

"""
    GraphAgent
Combine with [`@agent`](@ref) to create an agent type for [`GraphSpace`](@ref).
It attributes the fields `id::Int, pos::Int` to the start of the agent type.
"""
mutable struct GraphAgent <: AbstractAgent
    id::Int
    pos::Int
end

"""
    GridAgent{D}
Combine with [`@agent`](@ref) to create an agent type for `D`-dimensional
[`GraphSpace`](@ref). It attributes the fields `id::Int, pos::NTuple{D, Int}`
to the start of the agent type.
"""
mutable struct GridAgent{D} <: AbstractAgent
    id::Int
    pos::Dims{D}
end

"""
    ContinuousAgent{D}
Combine with [`@agent`](@ref) to create an agent type for `D`-dimensional
[`ContinuousSpace`](@ref). It attributes the fields
`id::Int, pos::NTuple{D, Float64}, vel::NTuple{D, Float64}`
to the start of the agent type.
"""
mutable struct ContinuousAgent{D} <: AbstractAgent
    id::Int
    pos::NTuple{D,Float64}
    vel::NTuple{D,Float64}
end

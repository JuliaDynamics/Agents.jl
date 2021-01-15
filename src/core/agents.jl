export AbstractAgent, @agent, GraphAgent, GridAgent, ContinuousAgent

"""
All agents must be a mutable subtype of `AbstractAgent`.
Your agent type **must have** the `id` field as first field.
Depending on the space structure there might be a `pos` field of appropriate type
and a `vel` field of appropriate type.

Your agent type may have other additional fields relevant to your system,
for example variable quantities like "status" or other "counters".

## Examples
Imagine agents who have extra properties `weight, happy`. For a [`GraphSpace`](@ref)
we would define them like
```julia
mutable struct ExampleAgent <: AbstractAgent
    id::Int
    pos::Int
    weight::Float64
    happy::Bool
end
```
while for e.g. a [`ContinuousSpace`](@ref) we would use
```julia
mutable struct ExampleAgent <: AbstractAgent
    id::Int
    pos::NTuple{2, Float64}
    vel::NTuple{2, Float64}
    weight::Float64
    happy::Bool
end
```
where `vel` is optional, useful if you want to use [`move_agent!`](@ref) in continuous
space.
"""
abstract type AbstractAgent end

"""
    @agent Person GraphAgent begin
        age::Int
    end

Creates a struct for your agent which includes the mandatory fields required to operate
in a particular space.

Refer to the specific agent constructors below for more details.
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
    @agent Person GraphAgent begin
        age::Int
    end

Create an agent with the ability to operate on a [`GraphSpace`](@ref). Used in
conjunction with [`@agent`](@ref) the example above produces

```julia
mutable struct Person <: AbstractAgent
    id::Int
    pos::Int
    age::Int
end
```
"""
mutable struct GraphAgent <: AbstractAgent
    id::Int
    pos::Int
end

"""
    @agent Person GridAgent{2} begin
        age::Int
    end

Create an agent with the ability to operate on a [`GridSpace`](@ref). The supplied
integer value tells the agent the dimensionality of the grid.
Used in conjunction with [`@agent`](@ref) the example above produces

```julia
mutable struct Person <: AbstractAgent
    id::Int
    pos::Dims{2}
    age::Int
end
```
"""
mutable struct GridAgent{D} <: AbstractAgent
    id::Int
    pos::Dims{D}
end

"""
    @agent Person ContinuousAgent{2} begin
        vel::NTuple{2,Float64}
        age::Int
    end

Create an agent with the ability to operate on a [`ContinuousSpace`](@ref).
The supplied integer value tells the agent the dimensionality of the grid.
Used in conjunction with [`@agent`](@ref) the example above produces

```julia
mutable struct Person <: AbstractAgent
    id::Int
    pos::NTuple{2,Float64}
    vel::NTuple{2,Float64}
    age::Int
end
```

Note that `vel`ocity is not a *required* property in `ContinuousSpace`s, although it is
used extensively. The above example showcases how best to add this property.
"""
mutable struct ContinuousAgent{D} <: AbstractAgent
    id::Int
    pos::NTuple{D,Float64}
end


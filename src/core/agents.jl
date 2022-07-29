export AbstractAgent, @agent
export GraphAgent, GridAgent, ContinuousAgent, OSMAgent

"""
    YourAgentType <: AbstractAgent
Agents participating in Agents.jl simulations are instances of user-defined Types that
are subtypes of `AbstractAgent`. It is almost always the case that mutable Types make
for a simpler modelling experience.

Your agent type(s) **must have** the `id::Int` field as first field.
If any space is used (see [Spaces](@ref)), a `pos` field of appropriate type
is also mandatory. Each space may also require additional fields that may,
or may not be communicated as part of the public API.

Your agent type may have other additional fields relevant to your system,
for example variable quantities like "status" or other "counters".

Use [`@agent`](@ref) to create `YourAgentType` for usage with Agents.jl.
"""
abstract type AbstractAgent end

"""
    @agent YourAgentType{X} AnotherAgentType [OptionalSupertype] begin
        extra_property::X
        other_extra_property::Int
        # etc...
    end

Define an agent struct which includes all fields that `AnotherAgentStruct` has,
as well as any additional ones the user may provide via the `begin` block.
See below for examples.

Using `@agent` is **the recommended way to create agent types** for using in Agents.jl.
Structs created with `@agent` always subtype `AbstractAgent`.
They cannot subtype each other, as all structs created from `@agent` are concrete types
and `AnotherAgentType` itself is also concrete (only concrete types have fields).
If you want `YourAgentType` to subtype something other than `AbstractAgent`, use
the optional argument `OptionalSupertype` (which itself must then subtype `AbstractAgent`).

The macro `@agent` is useful in two situations:
1. You want to include the mandatory fields for a particular space.
   In this case you would use one of the default agent types (see below).
2. You want a convenient way to include fields from another, already existing struct.

The existing default agent types are:
- [`GraphAgent`](@ref)
- [`GridAgent`](@ref)
- [`ContinuousAgent`](@ref)
- [`OSMAgent`](@ref)

Remember that `id, pos` are fields that will always be attributed to the new type
and a user should **never directly manipulate these fields**. Instead,
use functions like [`move_agent!`](@ref) etc., to change e.g., the position.

## Examples
### Example without optional hierarchy
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
and then, one can even do
```julia
@agent Baker{T} Person{T} begin
    breadz_per_day::T
end
```
which would make
```julia
mutable struct Baker{T} <: AbstractAgent
    id::Int
    pos::NTuple{2, Int}
    age::Int
    moneyz::T
    breadz_per_day::T
end
```
### Exaple with optional hierachy
An alternative way to make the above structs, that also establishes
a subtyping hierachy would be to do:
```julia
abstract type AbstractPerson{T} <: AbstractAgent end

@agent Person{T} GridAgent{2} AbstractPerson{T} begin
    age::Int
    moneyz::T
end

@agent Baker{T} Person{T} AbstractPerson{T} begin
    breadz_per_day::T
end
```
which would now make both `Baker, Person` subtypes of `AbstractPerson`.
"""
macro agent(base_type, new_name, extra_fields)
    # This macro was generated with the guidance of @rdeits on Discourse:
    # https://discourse.julialang.org/t/
    # metaprogramming-obtain-actual-type-from-symbol-for-field-inheritance/84912

    # We start with a quote. All macros return a quote to be evaluated
    quote
        let
            # Here we collect the field names and types from the base type
            # Because the base type already exists, we escape the symbols to obtain it
            base_fieldnames = fieldnames($(esc(base_type)))
            base_fieldtypes = [t for t in getproperty($(esc(base_type)), :types)]
            base_fields = [:($f::$T) for (f, T) in zip(base_fieldnames, base_fieldtypes)]
            # Then, we prime the additional name and fields into QuoteNodes
            # We have to do this to be able to interpolate them into an inner quote.
            name = $(QuoteNode(new_name))
            additional_fields = $(QuoteNode(extra_fields.args))
            # Now we start an inner quote. This is because our macro needs to call `eval`
            # However, this should never happen inside the main body of a macro
            # There are several reasons for that, see the cited discussion at the top
            expr = quote
                mutable struct $name <: AbstractAgent
                    $(base_fields...)
                    $(additional_fields...)
                end
            end
            # @show expr # uncomment this to see that the final expression looks as desired
            eval(expr)
        end
    end
end
# TODO: I do not know how to merge these two macros to remove code duplication.
# There should be away that only the 4-argument version is used
# and the 3-argument version just passes `AbstractAgent` to the 4-argument.
macro agent(base_type, new_name, supertype, extra_fields)
    # This macro was generated with the guidance of @rdeits on Discourse:
    # https://discourse.julialang.org/t/
    # metaprogramming-obtain-actual-type-from-symbol-for-field-inheritance/84912

    # We start with a quote. All macros return a quote to be evaluated
    quote
        let
            # Here we collect the field names and types from the base type
            # Because the base type already exists, we escape the symbols to obtain it
            base_fieldnames = fieldnames($(esc(base_type)))
            base_fieldtypes = [t for t in getproperty($(esc(base_type)), :types)]
            base_fields = [:($f::$T) for (f, T) in zip(base_fieldnames, base_fieldtypes)]
            # Then, we prime the additional name and fields into QuoteNodes
            # We have to do this to be able to interpolate them into an inner quote.
            name = $(QuoteNode(new_name))
            additional_fields = $(QuoteNode(extra_fields.args))
            supertype_quoted = $(QuoteNode(supertype))
            # Now we start an inner quote. This is because our macro needs to call `eval`
            # However, this should never happen inside the main body of a macro
            # There are several reasons for that, see the cited discussion at the top
            expr = quote
                mutable struct $name <: $supertype_quoted
                    $(base_fields...)
                    $(additional_fields...)
                end
            end
            # @show expr # uncomment this to see that the final expression looks as desired
            eval(expr)
        end
    end
end

# TODO: Move all type creation in the space files.

"""
    GraphAgent
The minimal agent struct for usage with [`GraphSpace`](@ref).
It has the fields `id::Int, pos::Int`. See also [`@agent`](@ref).
"""
mutable struct GraphAgent <: AbstractAgent
    id::Int
    pos::Int
end


# TODO: Rework the remaining docstrings as the above one.


"""
    GridAgent{D}
Combine with [`@agent`](@ref) to create an agent type for `D`-dimensional
[`GridSpace`](@ref). It attributes the fields `id::Int, pos::NTuple{D,Int}`
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
`id::Int, pos::NTuple{D,Float64}, vel::NTuple{D,Float64}`
to the start of the agent type.
"""
mutable struct ContinuousAgent{D} <: AbstractAgent
    id::Int
    pos::NTuple{D,Float64}
    vel::NTuple{D,Float64}
end

"""
    OSMAgent
Combine with [`@agent`](@ref) to create an agent type for [`OpenStreetMapSpace`](@ref).
It attributes the fields
`id::Int, pos::Tuple{Int,Int,Float64}`
to the start of the agent type.
"""
mutable struct OSMAgent <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int,Float64}
end

export AbstractAgent, @agent, NoSpaceAgent

"""
    YourAgentType <: AbstractAgent
Agents participating in Agents.jl simulations are instances of user-defined Types that
are subtypes of `AbstractAgent`. New agent Types should be made with [`@agent`](@ref).

Your agent type(s) **must have** the `id::Int` field as first field.
In Julia versions ≥ v1.8, this must also be declared as a `const` field.
If any space is used (see [Spaces](@ref)), a `pos` field of appropriate type
is also mandatory. Each space may also require additional fields that may,
or may not, be communicated as part of the public API.

Your agent type may have any other additional fields relevant to your use case,
for example variable quantities like "status" or other "counters".
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
Structs created with `@agent` by default subtype `AbstractAgent`.
They cannot subtype each other, as all structs created from `@agent` are concrete types
and `AnotherAgentType` itself is also concrete (only concrete types have fields).
If you want `YourAgentType` to subtype something other than `AbstractAgent`, use
the optional argument `OptionalSupertype` (which itself must then subtype `AbstractAgent`).

The macro `@agent` has two primary uses:
1. To include the mandatory fields for a particular space in your agent struct.
   In this case you would use one of the default agent types as `AnotherAgentType`.
2. A convenient way to include fields from another, already existing struct.

The existing default agent types are:
- [`NoSpaceAgent`](@ref)
- [`GraphAgent`](@ref)
- [`GridAgent`](@ref)
- [`ContinuousAgent`](@ref)
- [`OSMAgent`](@ref)

You should **never directly manipulate the mandatory fields `id, pos`**
that the resulting new agent type will have.
The `id` is an unchangable field (and in Julia versions ≥ v1.8 this is enforced).
Use functions like [`move_agent!`](@ref) etc., to change the position.

You can use the `@doc` macro from Julia to document the generated struct if you wish so.

## Examples
### Example without optional hierarchy
Using
```julia
@agent Person{T} GridAgent{2} begin
    age::Int
    moneyz::T
end
```
will create an agent appropriate for using with 2-dimensional [`GridSpace`](@ref)
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
a user-specific subtyping hierachy would be to do:
```julia
abstract type AbstractHuman <: AbstractAgent end

@agent Worker GridAgent{2} AbstractHuman begin
    age::Int
    moneyz::Float64
end

@agent Fisher Worker AbstractHuman begin
    fish_per_day::Float64
end
```
which would now make both `Human, Fisher` subtypes of `AbstractPerson`.

### Example highlighting problems with parametric types
Notice that in Julia parametric types are union types.
Hence, the following cannot be used:
```julia
@agent Dummy{T} GridAgent{2} begin
    moneyz::T
end

@agent Fisherino{T} Dummy{T} begin
    fish_per_day::T
end
```
You will get an error in the definition of `Fisherino`, because the fields of
`Dummy{T}` cannot be obtained, because it is a union type. Same with using `Dummy`.
You can only use `Dummy{Float64}`.

### Example with common dispatch and no subtyping
It may be that you do not even need to create a subtyping relation if you want
to utilize multiple dispatch. Consider the example:
```julia
@agent CommonTraits GridSpace{2} begin
    age::Int
    speed::Int
    energy::Int
end
```
and then two more structs are made from these traits:
```julia
@agent Bird CommonTraits begin
    height::Float64
end

@agent Rabbit CommonTraits begin
    underground::Bool
end
```

If you wanted a function that dispatches to both `Rabbit, Bird`, you only have to define:
```julia
Animal = Union{Bird, Rabbit}
f(x::Animal) = ... # uses `CommonTraits` fields
```
However, it should also be said, that there is no real reason here to explicitly
type-annotate `x::Animal` in `f`. Don't annotate any type. Annotating a type
only becomes useful if there are at least two "abstract" groups, like `Animal, Person`.
Then it would make sense to define
```julia
Person = Union{Fisher, Baker}
f(x::Animal) = ... # uses `CommonTraits` fields
f(x::Person) = ... # uses fields that all "persons" have
```
"""
macro agent(new_name, base_type, extra_fields)
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
            # It is important to evaluate the macro in the module that it was called at
            Core.eval($(__module__), expr)
        end
    end
end
# TODO: I do not know how to merge these two macros to remove code duplication.
# There should be away that only the 4-argument version is used
# and the 3-argument version just passes `AbstractAgent` to the 4-argument.
macro agent(new_name, base_type, supertype, extra_fields)
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
                mutable struct $name <: $$(esc(supertype))
                    $(base_fields...)
                    $(additional_fields...)
                end
            end
            # @show expr # uncomment this to see that the final expression looks as desired
            # It is important to evaluate the macro in the module that it was called at
            Core.eval($(__module__), expr)
        end
    end
end


"""
    NoSpaceAgent <: AbstractAgent
The minimal agent struct for usage with `nothing` as space (i.e., no space).
It has the field `id::Int`. See also [`@agent`](@ref).
"""
mutable struct NoSpaceAgent <: AbstractAgent
    id::Int
end
export AbstractAgent, @agent, NoSpaceAgent

"""
    YourAgentType <: AbstractAgent

Agents participating in Agents.jl simulations are instances of user-defined Types that
are subtypes of `AbstractAgent`.

Your agent type(s) **must have** the `id::Int` field as first field.
If any space is used (see [Available spaces](@ref)), a `pos` field of appropriate type
is also mandatory. The core model structure, and each space,
may also require additional fields that may,
or may not, be communicated as part of the public API.

The [`@agent`](@ref) macro ensures that all of these constrains are in place
and hence it is the recommended way to generate new agent types.
"""
abstract type AbstractAgent end

"""
    @agent YourAgentType{X} AnotherAgentType [OptionalSupertype] begin
        extra_property::X
        other_extra_property::Int
        # etc...
    end

Define an agent struct which includes all fields that `AnotherAgentType` has,
as well as any additional ones the user may provide via the `begin` block.
See below for examples.

Using `@agent` is the only supported way to create agent types for Agents.jl.

Structs created with `@agent` by default subtype `AbstractAgent`.
They cannot subtype each other, as all structs created from `@agent` are concrete types
and `AnotherAgentType` itself is also concrete (only concrete types have fields).
If you want `YourAgentType` to subtype something other than `AbstractAgent`, use
the optional argument `OptionalSupertype` (which itself must then subtype `AbstractAgent`).

## Usage

The macro `@agent` has two primary uses:
1. To include the mandatory fields for a particular space in your agent struct.
   In this case you would use one of the minimal agent types as `AnotherAgentType`.
2. A convenient way to include fields from another, already existing struct.

The existing minimal agent types are:
- [`NoSpaceAgent`](@ref)
- [`GraphAgent`](@ref)
- [`GridAgent`](@ref)
- [`ContinuousAgent`](@ref)
- [`OSMAgent`](@ref)

All will attribute an `id::Int` field, and besides `NoSpaceAgent` will also attribute
a `pos` field. You should **never directly manipulate the mandatory fields `id, pos`**
that the resulting new agent type will have. The `id` is an unchangeable field.
Use functions like [`move_agent!`](@ref) etc., to change the position.

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
It is also possible to specify that some fields are immutable
using the special `constants` variable inside the macro:
```julia
@agent Person{T} GridAgent{2} begin
    age::Int
    moneyz::T
    constants = (:age, )
end

agent = Person(1, (1, 1), 40, 2000)
agent.moneyz = 1000
agent.age = 20 # this throws an error
```
Notice that you can also use default values for some fields, in this case you 
will need to specify the field names with the non-default values
```julia
@agent Person{T} GridAgent{2} begin
    age::Int = 30
    moneyz::T
end
# default age value
Person(id = 1, pos = (1, 1), moneyz = 2000)
# new age value
Person(1, (1, 1), 40, 2000)
```
### Example with optional hierarchy
An alternative way to make the above structs, that also establishes
a user-specific subtyping hierarchy would be to do:
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
which would now make both `Fisher` and `Worker` subtypes of `AbstractHuman`.
```julia
julia> supertypes(Fisher)
(Fisher, AbstractHuman, AbstractAgent, Any)

julia> supertypes(Worker)
(Worker, AbstractHuman, AbstractAgent, Any)
```
Note that `Fisher` will *not* be a subtype of `Worker` although `Fisher` has
inherited the fields from `Worker`.

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
macro agent(new_name, base_type, super_type, extra_fields)
    # This macro was generated with the guidance of @rdeits on Discourse:
    # https://discourse.julialang.org/t/
    # metaprogramming-obtain-actual-type-from-symbol-for-field-inheritance/84912

    # We start with a quote. All macros return a quote to be evaluated
    quote
        let
            # Here we collect the field names and types from the base type
            # Because the base type already exists, we escape the symbols to obtain it
            base_T = $(esc(base_type))
            base_fieldnames = fieldnames(base_T)
            base_fieldtypes = fieldtypes(base_T)
            base_fieldconsts = isconst.(base_T, base_fieldnames)
            iter_fields = zip(base_fieldnames, base_fieldtypes, base_fieldconsts)
            base_fields = [c ? Expr(:const, :($f::$T)) : (:($f::$T))
                           for (f, T, c) in iter_fields]
            # Then, we prime the additional name and fields into QuoteNodes
            # We have to do this to be able to interpolate them into an inner quote.
            name = $(QuoteNode(new_name))
            additional_fields = $(QuoteNode(extra_fields.args))
            # here, we mutate any const fields defined by the consts variable in the macro
            additional_fields = filter(f -> typeof(f) != LineNumberNode, additional_fields)
            args_names = map(f -> f isa Expr ? f.args[1] : f, additional_fields)
            index_consts = findfirst(f -> f == :constants, args_names)
            if index_consts != nothing
                consts_args = eval(splice!(additional_fields, index_consts))
                for arg in consts_args
                    i = findfirst(a -> a == arg, args_names)
                    additional_fields[i] = Expr(:const, additional_fields[i])
                end
            end
            # Now we start an inner quote. This is because our macro needs to call `eval`
            # However, this should never happen inside the main body of a macro
            # There are several reasons for that, see the cited discussion at the top
            expr = quote
                # Also notice that we escape supertype and interpolate it twice
                # because this is expected to already be defined in the calling module
                @kwdef mutable struct $name <: $$(esc(super_type))
                    $(base_fields...)
                    $(additional_fields...)
                end
            end
            # @show expr # uncomment this to see that the final expression looks as desired
            # It is important to evaluate the macro in the module that it was called at
            Core.eval($(__module__), expr)
        end
        # allow attaching docstrings to the new struct, issue #715
        Core.@__doc__($(esc(Docs.namify(new_name))))
        nothing
    end
end

macro agent(new_name, base_type, extra_fields)
    # Here we nest one macro call into another because there is no way to provide 
    # defaults for macro arguments. We proceed to call the actual macro with the default
    # `super_type = AbstractAgent`. This requires us to disable 'macro hygiene', see here
    # for a brief explanation of the potential issues with this: 
    # https://discourse.julialang.org/t/calling-a-macro-from-within-a-macro-revisited/19680/16?u=fbanning
    esc(quote
        Agents.@agent($new_name, $base_type, Agents.AbstractAgent, $extra_fields)
    end)
end

"""
    NoSpaceAgent <: AbstractAgent
The minimal agent struct for usage with `nothing` as space (i.e., no space).
It has the field `id::Int`, and potentially other internal fields that
are not documented as part of the public API. See also [`@agent`](@ref).
"""
mutable struct NoSpaceAgent <: AbstractAgent
    id::Int
end

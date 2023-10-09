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
and hence it is the **the only supported way to create agent types**.
"""
abstract type AbstractAgent end

__AGENT_GENERATOR__ = Dict{Symbol, Expr}()

"""
    @agent struct YourAgentType{X}(AnotherAgentType) [<: OptionalSupertype]
        extra_property::X
        other_extra_property_with_default::Bool = true
        const other_extra_const_property::Int
        # etc...
    end

Define an agent struct which includes all fields that `AnotherAgentType` has,
as well as any additional ones the user may provide.
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
@agent struct Person{T}(GridAgent{2}) 
    age::Int
    moneyz::T
end
```
will create an agent appropriate for using with 2-dimensional [`GridSpace`](@ref)
```julia
mutable struct Person{T} <: AbstractAgent
    id::Int
    pos::NTuple{2, Int}
    const age::Int
    moneyz::T
end
```
Notice that you can also use default values for some fields, in this case you 
will need to specify the field names with the non-default values
```julia
@agent struct Person2{T}(GridAgent{2})
    age::Int = 30
    moneyz::T
end
# default age value
Person2(id = 1, pos = (1, 1), moneyz = 2000)
# new age value
Person2(1, (1, 1), 40, 2000)
```
### Example with optional hierarchy
An alternative way to make the above structs, that also establishes
a user-specific subtyping hierarchy would be to do:
```julia
abstract type AbstractHuman <: AbstractAgent end

@agent struct Worker(GridAgent{2}) <: AbstractHuman
    age::Int
    moneyz::Float64
end

@agent struct Fisher(Worker) <: AbstractHuman
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
@agent struct Dummy{T}(GridAgent{2})
    moneyz::T
end

@agent struct Fisherino{T}(Dummy{T})
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
@agent struct CommonTraits(GridAgent{2})
    age::Int
    speed::Int
    energy::Int
end
```
and then two more structs are made from these traits:
```julia
@agent struct Bird(CommonTraits)
    height::Float64
end

@agent struct Rabbit(CommonTraits)
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
macro agent(struct_repr)
    struct_parts = struct_repr.args[2:end]
    struct_def = struct_parts[1]
    if struct_def.head == :call
        new_type, base_type = struct_def.args
        abstract_type = :(Agents.AbstractAgent)
    else
        new_base_types, abstract_type =  struct_def.args
        new_type, base_type = new_base_types.args
    end
    new_type_args = vcat([t isa Symbol ? [] : t.args[2:end] for t in (new_type, base_type)]...)

    new_type_with_super = :($new_type <: $abstract_type)
    new_fields = struct_parts[2].args
    base_type_no_args = base_type isa Symbol ? base_type : base_type.args[1]
    new_type_no_args = new_type isa Symbol ? new_type : new_type.args[1]

    BaseAgent = __AGENT_GENERATOR__[base_type_no_args]

    old_args = BaseAgent.args[2:end][1] isa Symbol ? [] : BaseAgent.args[2:end][1].args[2:end]
    new_args = base_type isa Symbol ? [] : base_type.args[2:end]

    for (old, new) in zip(old_args, new_args)
        BaseAgent = expr_replace(BaseAgent, old, new)
    end

    #println(BaseAgent)
    #println(new_type_no_args)

    base_fields = BaseAgent.args[2:end][2].args

    expr = quote
            @kwdef mutable struct $new_type_with_super
                $(base_fields...)
                $(new_fields...)
           end
       end
    __AGENT_GENERATOR__[new_type_no_args] = :(mutable struct $new_type
                                                $(base_fields...)
                                                $(new_fields...)
                                              end)
    quote
        Base.@__doc__($(esc(expr)))
    end
end

function expr_replace(expr, old, new)
    function f(expr)
        expr == old && return deepcopy(new)
        if expr isa Expr
            for i in eachindex(expr.args)
                expr.args[i] = f(expr.args[i])
            end
        end
        expr
    end
    f(deepcopy(expr))
end


"""
    NoSpaceAgent <: AbstractAgent
The minimal agent struct for usage with `nothing` as space (i.e., no space).
It has the field `id::Int`, and potentially other internal fields that
are not documented as part of the public API. See also [`@agent`](@ref).
"""
mutable struct NoSpaceAgent
    const id::Int
end

__AGENT_GENERATOR__[:NoSpaceAgent] = :(mutable struct NoSpaceAgent
                                           const id::Int
                                       end)

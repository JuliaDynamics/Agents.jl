export AbstractAgent, @agent, @multiagent, NoSpaceAgent, kindof

###########################################################################################
# @agent
###########################################################################################
"""
    YourAgentType <: AbstractAgent

Agents participating in Agents.jl simulations are instances of user-defined types that
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

const __AGENT_GENERATOR__ = Dict{Symbol, Expr}()

__AGENT_GENERATOR__[:NoSpaceAgent] = :(mutable struct NoSpaceAgent <: AbstractAgent
                                           const id::Int
                                       end)

"""
    NoSpaceAgent <: AbstractAgent

The minimal agent struct for usage with `nothing` as space (i.e., no space).
It has the field `id::Int`, and potentially other internal fields that
are not documented as part of the public API. See also [`@agent`](@ref).
"""
@kwdef mutable struct NoSpaceAgent <: AbstractAgent
    const id::Int
end

"""
    @agent struct YourAgentType{X}(AgentTypeToInherit) [<: OptionalSupertype]
        extra_property::X
        other_extra_property_with_default::Bool = true
        const other_extra_const_property::Int
        # etc...
    end

Define an agent struct which includes all fields that `AgentTypeToInherit` has,
as well as any additional ones the user may provide. The macro supports all syntaxes
that the standard Julia `mutable struct` command allows for, such as `const` field
declaration or default values for some fields. Additionally, the resulting type
will always have a keyword constructor defined for it (using `@kwdef`).
See below for examples and see also [`@multiagent`](@ref).

Using `@agent` is the recommended way to create agent types for Agents.jl.

Structs created with `@agent` by default subtype `AbstractAgent`.
They cannot subtype each other, as all structs created from `@agent` are concrete types
and `AgentTypeToInherit` itself is also concrete (only concrete types have fields).
If you want `YourAgentType` to subtype something other than `AbstractAgent`, use
the optional argument `OptionalSupertype` (which itself must then subtype `AbstractAgent`).

## Usage

The macro `@agent` has two primary uses:

1. To include the mandatory fields for a particular space in your agent struct.
   In this case you would use one of the minimal agent types as `AnotherAgentType`.
2. A convenient way to include fields from another, already existing struct,
   thereby establishing a toolkit for "type inheritance" in Julia.

The existing minimal agent types are:

- [`NoSpaceAgent`](@ref)
- [`GraphAgent`](@ref)
- [`GridAgent`](@ref)
- [`ContinuousAgent`](@ref)
- [`OSMAgent`](@ref)

which describe which fields they will contribute to the new type.

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
Agents.jl has a convenience function [`add_agent!`](@ref) to create and add agents
to the model automatically. In the case you want to create some agents by yourself
you can use a constructor accepting the model as first argument so that internal fields,
such as the `id`, are set automatically
```julia
model = StandardABM(GridAgent{2}, GridSpace((10,10)))
a = GridAgent{2}(model, (3,4)) # the id is set automatically
```
"""
macro agent(struct_repr)
    new_type, base_type_spec, abstract_type, new_fields = decompose_struct_base(struct_repr)
    base_fields = compute_base_fields(base_type_spec)
    expr_new_type = :(mutable struct $new_type <: $abstract_type
                        $(base_fields...)
                        $(new_fields...)
                      end)
    new_type_no_params = namify(new_type)
    __AGENT_GENERATOR__[new_type_no_params] = MacroTools.prewalk(rmlines, expr_new_type)
    @capture(new_type, _{new_params__})
    new_params === nothing && (new_params = [])
    expr = quote
           @kwdef $expr_new_type
           $(new_type_no_params)(m::ABM, args...) =
               $(new_type_no_params)(Agents.nextid(m), args...)
           $(new_type_no_params)(m::ABM; kwargs...) =
               $(new_type_no_params)(; id = Agents.nextid(m), kwargs...)
           if $(new_params) != []
               $(new_type)(m::ABM, args...) where {$(new_params...)} =
                   $(new_type)(Agents.nextid(m), args...)
               $(new_type)(m::ABM; kwargs...) where {$(new_params...)} =
                   $(new_type)(; id = Agents.nextid(m), kwargs...)
           end
        end
    quote Base.@__doc__($(esc(expr))) end
end

###########################################################################################
# @multiagent
###########################################################################################
"""
    @multiagent struct YourAgentType{X,Y}(AgentTypeToInherit) [<: OptionalSupertype]
        @agent FirstAgentSubType{X}
            first_property::X # shared with second agent
            second_property_with_default::Bool = true
        end
        @agent SecondAgentSubType{X,Y}
            first_property::X = 3
            third_property::Y
        end
        # etc...
    end

Define multiple agent "subtypes", which are actually only variants of a unique
overarching type `YourAgentType`. This means that all "subtypes" are conceptual: they are simply
convenience functions defined that initialize the common proper type correctly
(see examples below for more). Because the "subtypes" are not real Julia `Types`,
you cannot use multiple dispatch on them. You also cannot distinguish them
on the basis of `typeof`, but need to use instead the `kindof` function.

See the [Tutorial](@ref) or the [performance comparison versus `Union` types](@ref multi_vs_union)
for why in most cases it is better to use `@multiagent` than making multiple
agent types manually.

Two different versions of `@multiagent` can be used by passing either `:opt_speed` or
`:opt_memory` as the first argument (before the `struct` keyword).
The first optimizes the agents representation for
speed, the second does the same for memory, at the cost of a moderate drop in performance.
By default it uses `:opt_speed`.

## Examples

Let's say you have this definition:

```
@multiagent :opt_speed struct Animal{T}(GridAgent{2})
    @agent struct Wolf
        energy::Float64 = 0.5
        ground_speed::Float64
        const fur_color::Symbol
    end
    @agent struct Hawk{T}
        energy::Float64 = 0.1
        ground_speed::Float64
        flight_speed::T
    end
end
```

Then you can create `Wolf` and `Hawk` agents normally, like so

```
hawk_1 = Hawk(1, (1, 1), 1.0, 2.0, 3)
hawk_2 = Hawk(; id = 2, pos = (1, 2), ground_speed = 2.3, flight_speed = 2)
wolf_1 = Wolf(3, (2, 2), 2.0, 3.0, :black)
wolf_2 = Wolf(; id = 4, pos = (2, 1), ground_speed = 2.0, fur_color = :white)
```

It is important to notice, though, that the `Wolf` and `Hawk` types are just
conceptual and all agents are actually of type `Animal` in this case.
The way to retrieve the variant of the agent is through the function `kindof` e.g.

```
kindof(hawk_1) # :Hawk
kindof(wolf_2) # :Wolf
```

See the [rabbit_fox_hawk](@ref) example to see how to use this macro in a model.

## Current limitations

- Impossibility to inherit from a compactified agent.
"""
macro multiagent(version, struct_repr)
    new_type, base_type_spec, abstract_type, agent_specs = decompose_struct_base(struct_repr)
    base_fields = compute_base_fields(base_type_spec)
    agent_specs_with_base = []
    for a_spec in agent_specs
        @capture(a_spec, @agent astruct_spec_)
        int_type, new_fields = decompose_struct(astruct_spec)
        push!(agent_specs_with_base,
              :(@kwdef mutable struct $int_type
                    $(base_fields...)
                    $(new_fields...)
                end))
    end
    t = :($new_type <: $abstract_type)
    c = @capture(new_type, new_type_n_{new_params__})
    if c == false 
        new_type_n = new_type
        new_params = []
    end
    new_params_no_constr = [p isa Expr && p.head == :(<:) ? p.args[1] : p for p in new_params]
    new_type_no_constr = :($new_type_n{$(new_params_no_constr...)})
    a_specs = :(begin $(agent_specs_with_base...) end)
    if version == QuoteNode(:opt_speed)
        expr = quote
                   MixedStructTypes.@compact_structs $t $a_specs
                   Agents.ismultiagentcompacttype(::Type{$(namify(new_type))}) = true
               end
    elseif version == QuoteNode(:opt_memory)
        expr = quote
                   MixedStructTypes.@sum_structs $t $a_specs
                   Agents.ismultiagentsumtype(::Type{$(namify(new_type))}) = true
               end
    else
        error("The version of @multiagent chosen was not recognized, use either `:opt_speed` or `:opt_memory` instead.")
    end

    expr_multiagent = :(Agents.ismultiagenttype(::Type{$(namify(new_type))}) = true)
    if new_params != []
        if version == QuoteNode(:opt_speed) 
            expr_multiagent_p = quote
                Agents.ismultiagenttype(::Type{$(new_type_no_constr)}) where {$(new_params...)} = true
                Agents.ismultiagentcompacttype(::Type{$(new_type_no_constr)}) where {$(new_params...)} = true
            end
        else
            expr_multiagent_p = quote
                Agents.ismultiagenttype(::Type{$(new_type_no_constr)}) where {$(new_params...)} = true
                Agents.ismultiagentsumtype(::Type{$(new_type_no_constr)}) where {$(new_params...)} = true
            end
        end
    else
        expr_multiagent_p = :()
    end

    expr = macroexpand(Agents, expr)

    expr = quote
               $expr
               $expr_multiagent
               $expr_multiagent_p
           end

    return esc(expr)
end

macro multiagent(struct_repr)
    return esc(:(@multiagent :opt_speed $struct_repr))
end

ismultiagenttype(::Type) = false
ismultiagentsumtype(::Type) = false
ismultiagentcompacttype(::Type) = false

function decompose_struct_base(struct_repr)
    if !@capture(struct_repr, struct new_type_(base_type_spec_) <: abstract_type_ new_fields__ end)
        @capture(struct_repr, struct new_type_(base_type_spec_) new_fields__ end)
    end
    abstract_type === nothing && (abstract_type = :(Agents.AbstractAgent))
    return new_type, base_type_spec, abstract_type, new_fields
end

function decompose_struct(struct_repr)
    if !@capture(struct_repr, struct new_type_ new_fields__ end)
        @capture(struct_repr, struct new_type_ new_fields__ end)
    end
    return new_type, new_fields
end

function compute_base_fields(base_type_spec)
    base_agent = __AGENT_GENERATOR__[namify(base_type_spec)]
    @capture(base_agent, mutable struct base_type_general_ <: _ __ end)
    old_args = base_type_general isa Symbol ? [] : base_type_general.args[2:end]
    new_args = base_type_spec isa Symbol ? [] : base_type_spec.args[2:end]
    for (old, new) in zip(old_args, new_args)
        base_agent = MacroTools.postwalk(ex -> ex == old ? new : ex, base_agent)
    end
    @capture(base_agent, mutable struct _ <: _ base_fields__ end)
    return base_fields
end

"""
    kindof(agent::AbstractAgent) → kind::Symbol

Return the "kind" (instead of type) of the agent, which is the name given to the
agent subtype when it was created with [`@multiagent`](@ref).
"""
function MixedStructTypes.kindof(a::AbstractAgent)
    throw(ArgumentError("Agent of type $(typeof(a)) has not been created via `@multiagent`."))
end

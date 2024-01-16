export AbstractAgent, @agent, @compact, NoSpaceAgent

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
    NoSpaceAgent <: AbstractAgent
The minimal agent struct for usage with `nothing` as space (i.e., no space).
It has the field `id::Int`, and potentially other internal fields that
are not documented as part of the public API. See also [`@agent`](@ref).
"""
__AGENT_GENERATOR__[:NoSpaceAgent] = :(mutable struct NoSpaceAgent <: AbstractAgent
                                           const id::Int
                                       end)
eval(__AGENT_GENERATOR__[:NoSpaceAgent])

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

"""
    @compact struct YourCompactedAgentType{X,Y}(BaseAgentType) [<: OptionalSupertype]
        @agent FirstAgentType{X}
            first_property::X # shared with second agent
            second_property_with_default::Bool = true
        end
        @agent SecondAgentType{X,Y}
            first_property::X = 3
            third_property::Y
        end
        # etc...
    end

Compactify multiple agents in a single type. Each agent has a `type` field which
defines which type of agent it is. Convenient constructors for each agent type are 
also provided.

Using this macro can be useful for performance of multi-agents models because combining
multiple agents in only one avoids dynamic dispatch and abstract containers problems, 
at the cost of more memory consumption. 

## Examples

Let's say you have this definition:

```
@compact struct Animal{T}(GridAgent{2})
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
The way to retrieve the group to which an agent belongs is through its `type` 
field e.g.

```
hawk_1.type # :hawk
wolf_2.type # :wolf
```

See the [rabbit_fox_hawk](@ref) example to see how to use this macro in a model.

## Current limitations

- Impossibility to inherit from a compactified agent.
"""
macro compact(struct_repr)
    new_type, base_type_spec, abstract_type, agent_specs = decompose_struct_base(struct_repr)
    base_fields = compute_base_fields(base_type_spec)
    types_each, fields_each, default_each = [], [], []
    for a_spec in agent_specs
        @capture(a_spec, @agent astruct_spec_)
        a_comps = decompose_struct_no_base(astruct_spec)
        push!(types_each, a_comps[1])
        push!(fields_each, a_comps[3][1])
        push!(default_each, a_comps[3][2])
    end
    common_fields = intersect(fields_each...)
    noncommon_fields = setdiff(union(fields_each...), common_fields)
    common_fields_n = retrieve_fields_names(common_fields)
    noncommon_fields_n = retrieve_fields_names(noncommon_fields)
    if isempty(noncommon_fields)
        islazy = false
    else
        islazy = true
        noncommon_fields = [f.head == :const ? :(@lazy $(f.args[1])) : (:(@lazy $f)) 
                            for f in noncommon_fields]
    end
    expr_new_type = :(mutable struct $new_type <: $abstract_type
                        $(base_fields...)
                        type::Symbol
                        $(common_fields...)
                        $(noncommon_fields...)
                      end)

    expr_new_type = islazy ? :(@lazy $expr_new_type) : expr_new_type
    expr_functions = []
    for (a_t, a_f, a_d) in zip(types_each, fields_each, default_each)
        a_base_n = retrieve_fields_names(base_fields)
        a_spec_n = retrieve_fields_names(a_f)
        a_spec_n_d = [d != "#328723329" ? Expr(:kw, n, d) : (:($n)) 
                      for (n, d) in zip(a_spec_n, a_d)]
        f_params_kwargs = [a_base_n..., a_spec_n_d...]
        f_params_kwargs = Expr(:parameters, f_params_kwargs...)        
        f_params_args = [a_base_n..., a_spec_n...]
        f_params_args_with_T = [retrieve_fields_names(base_fields, true)..., 
                                retrieve_fields_names(a_f, true)...]
        a_spec_n2_d = [d != "#328723329" ? Expr(:kw, n, d) : (:($n)) 
                      for (n, d) in zip(retrieve_fields_names(a_f, true), a_d)]
        f_params_kwargs_with_T = [a_base_n..., a_spec_n2_d...]
        f_params_kwargs_with_T = Expr(:parameters, f_params_kwargs_with_T...)
        type = Symbol(lowercase(string(namify(a_t))))
        f_inside_args = [common_fields_n..., noncommon_fields_n...]
        f_inside_args = [f in a_spec_n ? f : (:(Agents.uninit)) for f in f_inside_args]
        f_inside_args = [a_base_n..., Expr(:quote, type), f_inside_args...]
        @capture(a_t, a_t_n_{a_t_p__})
        a_t_p === nothing && (a_t_p = [])
        @capture(new_type, new_type_n_{new_type_p__})
        if new_type_p === nothing 
            new_type_n, new_type_p = new_type, []
        end
        new_type_p = [t in a_t_p ? t : (:(Agents.LazilyInitializedFields.Uninitialized)) 
                      for t in new_type_p]
        expr_function_kwargs = :(
            function $(namify(a_t))($f_params_kwargs)
                return $(namify(new_type))($(f_inside_args...))
            end
            )
        expr_function_args = :(
            function $(namify(a_t))($(f_params_args...))
                return $(namify(new_type))($(f_inside_args...))
            end
            )
        if !isempty(new_type_p)
            expr_function_args_with_T = :(
                function $(namify(a_t))($(f_params_args_with_T...)) where {$(a_t_p...)}
                    return $new_type_n{$(new_type_p...)}($(f_inside_args...))
                end
                )
            expr_function_kwargs_with_T = :(
                function $(namify(a_t))($f_params_kwargs_with_T) where {$(a_t_p...)}
                    return $new_type_n{$(new_type_p...)}($(f_inside_args...))
                end
                )
        else
            expr_function_args_with_T = :()
            expr_function_kwargs_with_T = :()
        end
        remove_prev_functions = remove_prev_methods(a_t)
        push!(expr_functions, remove_prev_functions)
        push!(expr_functions, expr_function_kwargs)
        push!(expr_functions, expr_function_args)
        push!(expr_functions, expr_function_args_with_T)
        push!(expr_functions, expr_function_kwargs_with_T)
    end
    expr = quote 
            $(Base.@__doc__ expr_new_type)
            $(expr_functions...)
            $(namify(new_type))
           end
    return esc(expr)
end

function decompose_struct_base(struct_repr)
    if !@capture(struct_repr, struct new_type_(base_type_spec_) <: abstract_type_ new_fields__ end)
        @capture(struct_repr, struct new_type_(base_type_spec_) new_fields__ end)
    end
    abstract_type === nothing && (abstract_type = :(Agents.AbstractAgent))
    return new_type, base_type_spec, abstract_type, new_fields
end

function decompose_struct_no_base(struct_repr, split_default=true)
    if !@capture(struct_repr, struct new_type_ <: abstract_type_ new_fields__ end)
        @capture(struct_repr, struct new_type_ new_fields__ end)
    end
    abstract_type === nothing && (abstract_type = :(Agents.AbstractAgent))
    if split_default
        new_fields_with_defs = [[], []]
        for f in new_fields
            if !@capture(f, t_ = k_)
                @capture(f, t_)
                k = "#328723329"
            end
            push!(new_fields_with_defs[1], t)
            push!(new_fields_with_defs[2], k)
        end
        new_fields = new_fields_with_defs
    end
    return new_type, abstract_type, new_fields
end

function decompose_struct(struct_repr)
    if !@capture(struct_repr, struct new_type_(base_type_spec_) <: abstract_type_ new_fields__ end)
        @capture(struct_repr, struct new_type_(base_type_spec_) new_fields__ end)
    end
    abstract_type === nothing && (abstract_type = :(Agents.AbstractAgent))
    return new_type, base_type_spec, abstract_type, new_fields
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

function retrieve_fields_names(fields, only_consts = false)
    field_names = []
    for f in fields
        f.head == :const && (f = f.args[1])
        !only_consts && f.head == :(::) && (f = f.args[1])
        push!(field_names, f)
    end
    return field_names
end
    
function remove_prev_methods(a_t)
    return :(if @isdefined $(namify(a_t))
                for m in methods($(namify(a_t)))
                    Base.delete_method(m)
                end
            end)

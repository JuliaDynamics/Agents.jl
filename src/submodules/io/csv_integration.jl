using CSV
using DataFrames

"""
    AgentsIO.populate_from_csv!(model, filename [, agent_type, col_map]; row_number_is_id, kwargs...)

Populate the given `model` using CSV data contained in `filename`. Use `agent_type` to
specify the type of agent to create (In the case of multi-agent models) or a function
that returns an agent to add to the model. The CSV row is splatted into the `agent_type`
constructor/function.

`col_map` is a `Dict{Symbol,Int}` specifying a mapping of keyword-arguments to row number.
If `col_map` is specified, the specified data is splatted as keyword arguments.

The keyword `row_number_is_id = false` specifies whether the row number will be passed as
the first argument (or as `id` keyword) to `agent_type`.

Any other keyword arguments are forwarded to `CSV.Rows`. If the `types` keyword is not
specified and `agent_type` is a struct, then the mapping from struct field to type will be used.
`Tuple{...}` fields will be suffixed with `_1`, `_2`, ... similarly to [`AgentsIO.dump_to_csv`](@ref)

For example,
```
struct Foo <: AbstractAgent
    id::Int
    pos::NTuple{2,Int}
    foo::Tuple{Int,String}
end

model = StandardABM(Foo, ...)
AgentsIO.populate_from_csv!(model, "test.csv")
```
Here, `types` will be inferred to be
```
Dict(
    :id => Int,
    :pos_1 => Int,
    :pos_2 => Int,
    :foo_1 => Int,
    :foo_2 => String,
)
```
It is not necessary for all these fields to be present as columns in the CSV. Any column
names that match will be converted to the appropriate type. There should exist a constructor
for `Foo` taking the appropriate combination of fields as parameters.

If `"test.csv"` contains the following columns: `pos_1, pos_2, foo_1, foo_2`, then `model`
can be populated as `AgentsIO.populate_from_csv!(model, "test.csv"; row_number_is_id = true)`.
"""
function populate_from_csv!(
    model::ABM{S},
    filename,
    agent_type::B = agenttype(model),
    col_map::Dict{Symbol,Int} = Dict{Symbol,Int}();
    row_number_is_id = false,
    kwargs...,
) where {B <: Union{Type{<:AbstractAgent},Function},S}
    @assert(
        agent_type isa Function || !(agent_type isa Union),
        "agent_type cannot be a Union. It must be a Function or concrete subtype of AbstractAgent"
    )
    if !haskey(kwargs, :types) && isstructtype(agent_type)
        kwargs = (
            kwargs...,
            types = Dict(
                fieldname(agent_type, i) => fieldtype(agent_type, i) for i in 1:fieldcount(agent_type)
            ),
        )
        for (k, v) in kwargs.types
            if v <: Tuple && isconcretetype(v)
                len = length(fieldtypes(v))
                for i in 1:len
                    kwargs.types[Symbol(k, "_$i")] = fieldtypes(v)[i]
                end
            end
        end
    end

    if isempty(col_map)
        if row_number_is_id
            for (id, row) in enumerate(CSV.Rows(read(filename); kwargs..., validate = false))
                add_agent_pos!(agent_type(id, row...), model)
            end
        else
            for row in CSV.Rows(read(filename); kwargs..., validate = false)
                add_agent_pos!(agent_type(row...), model)
            end
        end
    else
        if row_number_is_id
            for (id, row) in enumerate(CSV.Rows(read(filename); kwargs..., validate = false))
                add_agent_pos!(agent_type(; id, (k => row[v] for (k, v) in col_map)...), model)
            end
        else
            for row in CSV.Rows(read(filename); kwargs..., validate = false)
                add_agent_pos!(agent_type(; (k => row[v] for (k, v) in col_map)...), model)
            end
        end
    end
end

"""
    AgentsIO.dump_to_csv(filename, agents [, fields]; kwargs...)

Dump `agents` to the CSV file specified by `filename`. `agents` is any iterable
sequence of types, such as from [`allagents`](@ref). `fields` is an iterable sequence of
`Symbol`s specifying which fields of each agent are dumped. If not explicitly specified,
it is automatically inferred using `eltype(agents)`. All `kwargs...` are forwarded
to `CSV.write`.

All `Tuple{...}` fields are flattened to multiple columns suffixed by `_1`, `_2`...
similarly to [`AgentsIO.populate_from_csv!`](@ref)

For example,
```
struct Foo <: AbstractAgent
    id::Int
    pos::NTuple{2,Int}
    foo::Tuple{Int,String}
end

model = StandardABM(Foo, ...)
...
AgentsIO.dump_to_csv("test.csv", allagents(model))
```
The resultant `"test.csv"` file will contain the following columns: `id`, `pos_1`, `pos_2`,
`foo_1`, `foo_2`.
"""
function dump_to_csv(filename, agents, fields = collect(fieldnames(eltype(agents))); kwargs...)
    atype = eltype(agents)
    data = DataFrame()
    for f in fields
        ftype = fieldtype(atype, f)
        if ftype <: Tuple && isconcretetype(ftype)
            flen = length(fieldtypes(ftype))
            for i in 1:flen
                data[!, Symbol(f, "_$i")] = [getproperty(a, f)[i] for a in agents]
            end
        else
            data[!, f] = [getproperty(a, f) for a in agents]
        end
    end

    CSV.write(filename, data; kwargs...)
end

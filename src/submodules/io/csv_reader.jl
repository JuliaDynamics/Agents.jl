using CSV
import Base: parse

"""
    populate_from_csv!(filename, model, agent_type; kwargs...)

Populates the given `model` using data read from csv file at `filename`.
`agent_type` is either a subtype of `AbstractAgent` also used in `model` or
a function that returns an agent that can be added to the model. All keyword arguments
are forwarded to `CSV.Rows`. If `agent_type` is not a function, and the `types` keyword
argument is not specified, it is assumed that the columns in the csv file correspond
to fields of the struct.
"""
function populate_from_csv!(
    filename,
    model::ABM{S,A},
    agent_type::B;
    kwargs...
) where {A, B<:Type{<:A},S}
    !haskey(kwargs, :types) && (kwargs = (kwargs..., types = collect(fieldtypes(agent_type))))
    for row in CSV.Rows(filename; kwargs...)
        add_agent_pos!(agent_type(row...), model)
    end
end

function populate_from_csv!(
    filename,
    model::ABM{S,A},
    agent_type::Function;
    kwargs...
) where {S, A}
    for row in CSV.Rows(filename; kwargs...)
        add_agent_pos!(agent_type(row...), model)
    end
end

function Base.parse(::Type{NTuple{N,T}}, str::String; base::Int = 10) where {N,T}
    return Tuple(map(x -> parse(T, x; base), split(str[2:(end-1)], ", ")))
end
using CSV

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
    model::ABM{A},
    agent_type::B;
    kwargs...
) where {A, B<:Union{Type{<:A}, Function}}
    !(agent_type isa Function) && !haskey(kwargs, :types) && (kwargs[:types] = collect(fieldtypes(agent_type)))
    for row in Rows(filename; kwargs...)
        add_agent_pos!(agent_type(row...), model)
    end
end

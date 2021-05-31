using CSV

"""
    populate_from_csv!(filename, model, agent_type, col_map; kwargs...)

Populates the given `model` using data read from csv file at `filename`.
`agent_type` is either a subtype of `AbstractAgent` also used in `model` or
a function that returns an agent that can be added to the model. All keyword arguments
are forwarded to `CSV.Rows`. `col_map` is a map from keyword arguments of 
`agent_type` to the column index populating that argument.
"""
function populate_from_csv!(
    filename,
    model::ABM{S,A},
    agent_type::B,
    col_map::Dict{Symbol,Int};
    kwargs...
) where {A,B<:Type{<:A},S}
    for row in CSV.Rows(filename; kwargs...)
        add_agent_pos!(agent_type(; (k => row[v] for (k, v) in  col_map)...), model)
    end
end
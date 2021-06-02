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
    col_map::Dict{Symbol,Int} = Dict();
    kwargs...
) where {A,B<:Union{Type{<:A},Function},S}
    if !haskey(kwargs, :types) && isstructtype(agent_type)  
        kwargs[:types] = Dict(fieldname(agent_type, i) => fieldtype(agent_type, i) for i in 1:fieldcount(agent_type))
    end
    
    if isempty(col_map)
        for row in CSV.Rows(filename; kwargs...)
            add_agent_pos!(agent_type(row...), model)
        end
    else
        for row in CSV.Rows(filename; kwargs...)
            add_agent_pos!(agent_type(; (k => row[v] for (k, v) in  col_map)...), model)
        end
    end
end

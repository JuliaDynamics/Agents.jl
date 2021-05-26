using CSV

function populate_from_csv!(
    filename,
    model::ABM{A},
    agent_type::B;
    kwargs...
) where {A, B<:Union{Type{<:A}, Function}}
    !haskey(kwargs, :types) && (kwargs[:types] = collect(fieldtypes(agent_type)))
    for row in Rows(filename; kwargs...)
        add_agent_pos!(agent_type(row...), model)
    end
end

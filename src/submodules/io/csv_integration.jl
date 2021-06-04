using CSV
using DataFrames

"""
    populate_from_csv!(model, filename, agent_type, col_map; kwargs...)

Populates the given `model` using data read from csv file at `filename`.
`agent_type` is either a subtype of `AbstractAgent` also used in `model` or
a function that returns an agent that can be added to the model. All keyword arguments
are forwarded to `CSV.Rows`. `col_map` is a map from keyword arguments of 
`agent_type` to the column index populating that argument.
"""
function populate_from_csv!(
    model::ABM{S,A},
    filename,
    agent_type::B,
    col_map::Dict{Symbol,Int} = Dict{Symbol,Int}();
    kwargs...
) where {A,B<:Union{Type{<:A},Function},S}
    if !haskey(kwargs, :types) && isstructtype(agent_type)  
        kwargs = (kwargs..., types = Dict(fieldname(agent_type, i) => fieldtype(agent_type, i) for i in 1:fieldcount(agent_type)))
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
        for row in CSV.Rows(read(filename); kwargs...)
            add_agent_pos!(agent_type(row...), model)
        end
    else
        for row in CSV.Rows(read(filename); kwargs...)
            add_agent_pos!(agent_type(; (k => row[v] for (k, v) in  col_map)...), model)
        end
    end
end

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
module AgentsArrow

using Agents, Arrow

function Agents.writer_arrow(filename, data, append)
    if append
        Arrow.append(filename, data)
    else
        Arrow.write(filename, data; file = false)
    end
end

# TODO: Implement populate_from and dump_to functions for Arrow.jl

function AgentsIO.populate_from_arrow!()
    @error "Not yet implemented."
    return
end

function AgentsIO.dump_to_arrow()
    @error "Not yet implemented."
    return
end

end

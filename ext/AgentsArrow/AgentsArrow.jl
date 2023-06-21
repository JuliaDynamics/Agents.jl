module AgentsArrow

using Agents, Arrow

function Agents.writer_arrow(filename, data, append)
    if append
        Arrow.append(filename, data)
    else
        Arrow.write(filename, data; file = false)
    end
end

end

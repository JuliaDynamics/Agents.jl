mutable struct Agent1 <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    money::Int
end

mutable struct Agent2 <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    money::Int
end

mutable struct Agent3 <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    money::Int
end

mutable struct Agent4 <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    money::Int
end

mutable struct Agent5 <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    money::Int
end

mutable struct Agent6 <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    money::Int
end

mutable struct Agent7 <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    money::Int
end

mutable struct Agent8 <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    money::Int
end

mutable struct Agent9 <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    money::Int
end

mutable struct Agent10 <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    money::Int
end

mutable struct Agent11 <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    money::Int
end

mutable struct Agent12 <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    money::Int
end

mutable struct Agent13 <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    money::Int
end

mutable struct Agent14 <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    money::Int
end

mutable struct Agent15 <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    money::Int
end

function initialize_model(;n_agents=600, n_types=1, dims=(5,5))
    agent_types = [Agent1,Agent2,Agent3,Agent4,Agent5,Agent6,Agent7,Agent8,
        Agent9,Agent10,Agent11,Agent12,Agent13,Agent14,Agent15]
    agents_used = agent_types[1:n_types]
    space = GridSpace(dims)
    model = ABM(Union{agents_used...}, space, scheduler=random_activation, warn=false)
    id = 0
    agents_per_type = div(n_agents, n_types)
    for A in agents_used
        for _ in 1:agents_per_type
            id += 1
            agent = A(id, (0,0), 10)
            add_agent!(agent, model)
        end
    end
    return model
end

function agent_step!(agent, model)
    move!(agent, model)
    agents = get_node_agents(agent.pos, model)
    map(a->exchange!(agent, a), agents)
    return nothing
end


function move!(agent, model)
    neighbors = node_neighbors(agent, model)
    cell = rand(neighbors)
    move_agent!(agent, cell, model)
    return nothing
end

function exchange!(agent, other_agent)
    v1 = agent.money
    v2 = other_agent.money
    agent.money = v2
    other_agent.money = v1
    return nothing
end

function run_simulation(n_steps, n_reps; n_types)
    t = @timed for _ in 1:n_reps
        model = initialize_model(;n_types=n_types)
        step!(model, agent_step!, n_steps)
    end
    return t[2]/n_reps
end

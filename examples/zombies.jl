using Agents
using OpenStreetMapX
using OpenStreetMapXPlot
using Plots
gr()

mutable struct Zombie <: AbstractAgent
    id::Int
    pos::Int
    infected::Bool
end

function initialise()
    m = get_map_data(
        "test/data/reno_east3.osm",
        use_cache = false,
        trim_to_connected_graph = true,
    )

    model = ABM(Zombie, GraphSpace(m.g), properties = Dict(:osmmap => m))

    for _ in 1:100
        add_agent!(model, false)
    end

    patient_zero = random_agent(model)
    patient_zero.infected = true
    return model
end

function agent_step!(agent, model)
    np = nearby_positions(agent, model)
    new_pos = rand(np)
    move_agent!(agent, new_pos, model)

    if agent.infected
        map(a -> a.infected = true, nearby_agents(agent, model))
    else
        if any(a.infected for a in nearby_agents(agent, model))
            agent.infected = true
        end
    end
end

function get_coordinates(agent, model)
    getX(model.osmmap.nodes[model.osmmap.n[agent.pos]]),
    getY(model.osmmap.nodes[model.osmmap.n[agent.pos]])
end

ac(agent) = agent.infected ? :green : :black
as(agent) = agent.infected ? 6 : 5

function plotagents(model)
    # Essentially a cut down version on plotabm
    ids = model.scheduler(model)
    colors = [ac(model[i]) for i in ids]
    sizes = [as(model[i]) for i in ids]
    markers = :circle
    pos = [get_coordinates(model[i], model) for i in ids]

    scatter!(
        pos;
        markercolor = colors,
        markersize = sizes,
        markershapes = markers,
        label = "",
        markerstrokewidth = 0.5,
        markerstrokecolor = :black,
        markeralpha = 0.7,
    )
end

model = initialise()

frames = @animate for _ in 1:50
    step!(model, agent_step!, 1)
    plotmap(model.osmmap)
    plotagents(model)
end

gif(frames, "anim.gif", fps = 3)



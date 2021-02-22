mutable struct SugarSeeker <: AbstractAgent
    id::Int
    pos::Dims{2}
    vision::Int
    metabolic_rate::Int
    age::Int
    max_age::Int
    wealth::Int
end

function distances(pos, sugar_peaks, max_sugar)
    all_dists = Array{Int,1}(undef, length(sugar_peaks))
    for (ind, peak) in enumerate(sugar_peaks)
        d = round(Int, sqrt(sum((pos .- peak) .^ 2)))
        all_dists[ind] = d
    end
    return minimum(all_dists)
end

function sugar_caps(dims, sugar_peaks, max_sugar, dia = 4)
    sugar_capacities = zeros(Int, dims)
    for i in 1:dims[1], j in 1:dims[2]
        sugar_capacities[i, j] = distances((i, j), sugar_peaks, max_sugar)
    end
    for i in 1:dims[1]
        for j in 1:dims[2]
            sugar_capacities[i, j] = max(0, max_sugar - (sugar_capacities[i, j] ÷ dia))
        end
    end
    return sugar_capacities
end

"""
``` julia
sugarscape(;
    dims = (50, 50),
    sugar_peaks = ((10, 40), (40, 10)),
    growth_rate = 1,
    N = 250,
    w0_dist = (5, 25),
    metabolic_rate_dist = (1, 4),
    vision_dist = (1, 6),
    max_age_dist = (60, 100),
    max_sugar = 4,
)
```
Same as in [Sugarscape](@ref).
"""
function sugarscape(;
    dims = (50, 50),
    sugar_peaks = ((10, 40), (40, 10)),
    growth_rate = 1,
    N = 250,
    w0_dist = (5, 25),
    metabolic_rate_dist = (1, 4),
    vision_dist = (1, 6),
    max_age_dist = (60, 100),
    max_sugar = 4,
)
    sugar_capacities = sugar_caps(dims, sugar_peaks, max_sugar, 6)
    sugar_values = deepcopy(sugar_capacities)
    space = GridSpace(dims)
    properties = Dict(
        :growth_rate => growth_rate,
        :N => N,
        :w0_dist => w0_dist,
        :metabolic_rate_dist => metabolic_rate_dist,
        :vision_dist => vision_dist,
        :max_age_dist => max_age_dist,
        :sugar_values => sugar_values,
        :sugar_capacities => sugar_capacities,
    )
    model = AgentBasedModel(
        SugarSeeker,
        space,
        scheduler = random_activation,
        properties = properties,
    )
    for _ in 1:N
        add_agent_single!(
            model,
            rand(model.rng, vision_dist[1]:vision_dist[2]),
            rand(model.rng, metabolic_rate_dist[1]:metabolic_rate_dist[2]),
            0,
            rand(model.rng, max_age_dist[1]:max_age_dist[2]),
            rand(model.rng, w0_dist[1]:w0_dist[2]),
        )
    end
    return model, sugarscape_agent_step!, sugarscape_env!
end

function sugarscape_env!(model)
    # At each position, sugar grows back at a rate of $\alpha$ units per time-step up to the cell's capacity c.
    togrow = findall(
        x -> model.sugar_values[x] < model.sugar_capacities[x],
        1:length(positions(model)),
    )
    model.sugar_values[togrow] .+= model.growth_rate
end

function movement!(agent, model)
    newsite = agent.pos
    # find all unoccupied position within vision
    neighbors = nearby_positions(agent.pos, model, agent.vision)
    empty = collect(empty_positions(model))
    if length(empty) > 0
        # identify the one(s) with greatest amount of sugar
        available_sugar = (model.sugar_values[x,y] for (x, y) in empty)
        maxsugar = maximum(available_sugar)
        if maxsugar > 0
            sugary_sites_inds = findall(x -> x == maxsugar, collect(available_sugar))
            sugary_sites = empty[sugary_sites_inds]
            # select the nearest one (randomly if more than one)
            for dia in 1:(agent.vision)
                np = nearby_positions(agent.pos, model, dia)
                suitable = intersect(np, sugary_sites)
                if length(suitable) > 0
                    newsite = rand(model.rng, suitable)
                    break
                end
            end
            # move there and collect all the sugar in it
            newsite != agent.pos && move_agent!(agent, newsite, model)
        end
    end
    # update wealth (collected - consumed)
    agent.wealth += (model.sugar_values[newsite...] - agent.metabolic_rate)
    model.sugar_values[newsite...] = 0
    agent.age += 1
end

function replacement!(agent, model)
    # If the agent's sugar wealth become zero or less, it dies
    if agent.wealth <= 0 || agent.age >= agent.max_age
        kill_agent!(agent, model)
        # Whenever an agent dies, a young one is added to a random pos.
        # New agent has random attributes
        add_agent_single!(
            model,
            rand(model.rng, model.vision_dist[1]:model.vision_dist[2]),
            rand(model.rng, model.metabolic_rate_dist[1]:model.metabolic_rate_dist[2]),
            0,
            rand(model.rng, model.max_age_dist[1]:model.max_age_dist[2]),
            rand(model.rng, model.w0_dist[1]:model.w0_dist[2]),
        )
    end
end

function sugarscape_agent_step!(agent, model)
    movement!(agent, model)
    replacement!(agent, model)
end


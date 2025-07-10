using Agents, Random, CairoMakie

## 1. Agent Definition
@agent struct BoltzmannAgent(GridAgent{2})
    wealth::Int
end

## 2. Gini Coefficient Calculation Function
function gini(wealths::Vector{Int})
    n = length(wealths)
    if n <= 1
        return 0.0
    end
    sorted_wealths = sort(wealths)
    sum_wi = sum(sorted_wealths)
    if sum_wi == 0
        return 0.0
    end
    numerator = sum((2i - n - 1) * w for (i, w) in enumerate(sorted_wealths))
    denominator = n * sum_wi
    return numerator / denominator
end

## 3. Model Properties
function boltzmann_money_model(; num_agents=100, dims=(10, 10), seed=1234, initial_wealth=1)
    space = GridSpace(dims; periodic=true)
    rng = MersenneTwister(seed)
    properties = Dict(
        :gini_coefficient => 0.0, # Initialize gini_coefficient
    )

    model = StandardABM(BoltzmannAgent, space;
        (agent_step!)=boltz_step!,
        (model_step!)=boltz_model_step!,
        rng,
        scheduler=Schedulers.Randomly(),
        properties=properties
    )

    for _ in 1:num_agents
        add_agent_single!(BoltzmannAgent, model, rand(1:initial_wealth))
    end
    return model
end

## 4. Agent Step Function
function boltz_step!(agent::BoltzmannAgent, model::ABM)
    nearby_neighbors = collect(nearby_positions(agent.pos, model))
    if !isempty(nearby_neighbors)
        move_agent!(agent, rand(nearby_neighbors), model)
    end

    if agent.wealth > 0
        other_agents_in_cell = [a for a in agents_in_position(agent.pos, model) if a.id != agent.id]
        if !isempty(other_agents_in_cell)
            other_agent = rand(other_agents_in_cell)
            agent.wealth -= 1
            other_agent.wealth += 1
        end
    end
end

## 5. Model Step Function
function boltz_model_step!(model::ABM)
    wealths = [agent.wealth for agent in allagents(model)]
    model.gini_coefficient = gini(wealths)
end


## 6. Example Simulation and Analysis
model = boltzmann_money_model(num_agents=5, dims=(10, 10), initial_wealth=10)
figure, _ = abmplot(model;
    agent_color=a -> a.wealth,
    agent_size=a -> 8 + a.wealth * 0.5,
    title="Boltzmann Money Model - Final State (Post-Simulation)"
)
figure

adata = [:wealth]
mdata = [:gini_coefficient]

iterations = 200
data, mdata_df = run!(model, iterations; adata, mdata)
data.wealth


figure, _ = abmplot(model;
    agent_color=a -> a.wealth,
    agent_size=a -> 8 + a.wealth * 0.5,
    title="Boltzmann Money Model - Final State (Post-Simulation)"
)
figure

abmvideo(
    "boltz_model.mp4",
    model;
    frames=iterations,
    framerate=5,
    title="Boltzmann Money Model Simulation",
    agent_color=a -> a.wealth,
    agent_size=a -> 8 + a.wealth * 0.5,
)

# Plot Gini Coefficient over time
function plot_gini(mdata_df)
    figure = Figure()
    ax = Axis(figure[1, 1], title="Gini Coefficient Over Time")
    lines!(ax, 1:iterations+1, mdata_df.gini_coefficient,
        color=:blue, linewidth=2, label="Gini Coefficient")
    return figure
end
figure_gini = plot_gini(mdata_df)

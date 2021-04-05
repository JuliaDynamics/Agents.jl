# # Model of predator-prey dynamics

# The predator-prey model emulates the population dynamics of predator and prey animals who
# live in a common ecosystem and compete over limited resources. This model is an
# agent-based analog to the classic
# [Lotka-Volterra](https://en.wikipedia.org/wiki/Lotka%E2%80%93Volterra_equations)
# differential equation model. This example illustrates how to develop models with
# heterogeneous agents (sometimes referred to as a *mixed agent based model*).

# The environment is a two dimensional grid containing sheep, wolves and grass. In the
# model, wolves eat sheep and sheep eat grass. Their populations will oscillate over time
# if the correct balance of resources is achieved. Without this balance however, a
# population may become extinct. For example, if wolf population becomes too large,
# they will deplete the sheep and subsequently die of starvation.

# We will begin by loading the required packages and defining three subtypes of
# `AbstractAgent`: `Sheep`, Wolf, and `Grass`. All three agent types have `id` and `pos`
# properties, which is a requirement for all subtypes of `AbstractAgent` when they exist
# upon a `GridSpace`. Sheep and wolves have identical properties, but different behaviors
# as explained below. The property `energy` represents an animals current energy level.
# If the level drops below zero, the agent will die. Sheep and wolves reproduce asexually
# in this model, with a probability given by `reproduction_prob`. The property `Δenergy`
# controls how much energy is acquired after consuming a food source.

# Grass is a replenishing resource that occupies every position in the grid space. Grass can be
# consumed only if it is `fully_grown`. Once the grass has been consumed, it replenishes
# after a delay specified by the property `regrowth_time`. The property `countdown` tracks
# the delay between being consumed and the regrowth time.

# It is also available from the `Models` module as [`Models.predator_prey`](@ref).

using Agents
using Random # hide

mutable struct Sheep <: AbstractAgent
    id::Int
    pos::Dims{2}
    energy::Float64
    reproduction_prob::Float64
    Δenergy::Float64
end

mutable struct Wolf <: AbstractAgent
    id::Int
    pos::Dims{2}
    energy::Float64
    reproduction_prob::Float64
    Δenergy::Float64
end

mutable struct Grass <: AbstractAgent
    id::Int
    pos::Dims{2}
    fully_grown::Bool
    regrowth_time::Int
    countdown::Int
end
nothing # hide

# The function `initialize_model` returns a new model containing sheep, wolves, and grass
# using a set of pre-defined values (which can be overwritten). The environment is a two
# dimensional grid space, which enables animals to walk in all
# directions. Heterogeneous agents are specified in the model as a `Union`. Agents are
# scheduled `by_type`, which randomizes the order of agents with the constraint that agents
# of a particular type are scheduled consecutively.

function initialize_model(;
    n_sheep = 100,
    n_wolves = 50,
    dims = (20, 20),
    regrowth_time = 30,
    Δenergy_sheep = 4,
    Δenergy_wolf = 20,
    sheep_reproduce = 0.04,
    wolf_reproduce = 0.05,
)
    space = GridSpace(dims, periodic = false)
    model =
        ABM(Union{Sheep,Wolf,Grass}, space, scheduler = by_type(true, true), warn = false)
    id = 0
    for _ in 1:n_sheep
        id += 1
        energy = rand(1:(Δenergy_sheep*2)) - 1
        ## Note that we must instantiate agents before adding them in a mixed-ABM
        ## to confirm their type.
        sheep = Sheep(id, (0, 0), energy, sheep_reproduce, Δenergy_sheep)
        add_agent!(sheep, model)
    end
    for _ in 1:n_wolves
        id += 1
        energy = rand(1:(Δenergy_wolf*2)) - 1
        wolf = Wolf(id, (0, 0), energy, wolf_reproduce, Δenergy_wolf)
        add_agent!(wolf, model)
    end
    for p in positions(model)
        id += 1
        fully_grown = rand(model.rng, Bool)
        countdown = fully_grown ? regrowth_time : rand(model.rng, 1:regrowth_time) - 1
        grass = Grass(id, (0, 0), fully_grown, regrowth_time, countdown)
        add_agent!(grass, p, model)
    end
    return model
end
nothing # hide

# The function `agent_step!` is dispatched on each subtype in order to produce
# type-specific behavior. The `agent_step!` is similar for sheep and wolves: both lose 1
# energy unit by moving to an adjacent position and both consume a food source if available.
# If their energy level is below zero, an agent dies. Otherwise, the agent lives and
# reproduces with some probability.

function agent_step!(sheep::Sheep, model)
    move!(sheep, model)
    sheep.energy -= 1
    agents = collect(agents_in_position(sheep.pos, model))
    dinner = filter!(x -> isa(x, Grass), agents)
    eat!(sheep, dinner, model)
    if sheep.energy < 0
        kill_agent!(sheep, model)
        return
    end
    if rand(model.rng) <= sheep.reproduction_prob
        reproduce!(sheep, model)
    end
end

function agent_step!(wolf::Wolf, model)
    move!(wolf, model)
    wolf.energy -= 1
    agents = collect(agents_in_position(wolf.pos, model))
    dinner = filter!(x -> isa(x, Sheep), agents)
    eat!(wolf, dinner, model)
    if wolf.energy < 0
        kill_agent!(wolf, model)
        return
    end
    if rand(model.rng) <= wolf.reproduction_prob
        reproduce!(wolf, model)
    end
end
nothing # hide

# The behavior of grass functions differently. If it is fully grown, it is consumable.
# Otherwise, it cannot be consumed until it regrows after a delay specified by
# `regrowth_time`.

function agent_step!(grass::Grass, model)
    if !grass.fully_grown
        if grass.countdown <= 0
            grass.fully_grown = true
            grass.countdown = grass.regrowth_time
        else
            grass.countdown -= 1
        end
    end
end
nothing # hide

# Sheep and wolves move to a random adjacent position with the `move!` function.
function move!(agent, model)
    neighbors = nearby_positions(agent, model)
    position = rand(model.rng, collect(neighbors))
    move_agent!(agent, position, model)
end
nothing # hide

# Sheep and wolves have separate `eat!` functions. If a sheep eats grass, it will acquire
# additional energy and the grass will not be available for consumption until regrowth time
# has elapsed. If a wolf eats a sheep, the sheep dies and the wolf acquires more energy.

function eat!(sheep::Sheep, grass_array, model)
    isempty(grass_array) && return
    grass = grass_array[1]
    if grass.fully_grown
        sheep.energy += sheep.Δenergy
        grass.fully_grown = false
    end
end

function eat!(wolf::Wolf, sheep, model)
    if !isempty(sheep)
        dinner = rand(model.rng, sheep)
        kill_agent!(dinner, model)
        wolf.energy += wolf.Δenergy
    end
end
nothing # hide

# Sheep and wolves share a common reproduction method. Reproduction has a cost of 1/2 the
# current energy level of the parent. The offspring is an exact copy of the parent, with
# exception of `id`.

function reproduce!(agent, model)
    agent.energy /= 2
    id = nextid(model)
    A = typeof(agent)
    offspring = A(id, agent.pos, agent.energy, agent.reproduction_prob, agent.Δenergy)
    add_agent_pos!(offspring, model)
    return
end
nothing # hide

# ## Running the model
# We will run the model for 500 steps and record the number of sheep, wolves and consumable
# grass patches after each step. First: initialize the model.
using InteractiveDynamics
using CairoMakie
Random.seed!(23182) # hide
n_steps = 500
model = initialize_model()

# To view our starting population, we can build an overview plot:

offset(a::Sheep) = (0.2, 0.0)
offset(a::Wolf) = (-0.2, 0.0)
offset(a::Grass) = (0.0, 0.0)
mshape(a::Sheep) = '⚫'
mshape(a::Wolf) = '▲'
mshape(a::Grass) = '■'
mcolor(a::Sheep) = RGBAf0(1.0, 1.0, 1.0, 0.8)
mcolor(a::Wolf) = RGBAf0(0.2, 0.2, 0.2, 0.8)
mcolor(a::Grass) = cgrad([:brown, :green])[a.countdown/a.regrowth_time]
figure, = abm_plot(
    model;
    resolution = (800, 600),
    offset = offset,
    am = mshape,
    as = 22,
    ac = mcolor,
    scheduler = by_type((Grass, Sheep, Wolf), false),
)
figure
# Now, lets run the simulation and collect some data.

sheep(a) = typeof(a) == Sheep
wolves(a) = typeof(a) == Wolf
grass(a) = typeof(a) == Grass && a.fully_grown
adata = [(sheep, count), (wolves, count), (grass, count)]
results, _ = run!(model, agent_step!, n_steps; adata)

# The plot shows the population dynamics over time. Initially, wolves become extinct because they
# consume the sheep too quickly. The few remaining sheep reproduce and gradually reach an
# equilibrium that can be supported by the amount of available grass.
figure = Figure(resolution = (600, 400))
ax = figure[1, 1] = Axis(figure; xlabel = "Step", ylabel = "Population")
sheepl = lines!(ax, results.step, results.count_sheep, color = :blue)
wolfl = lines!(ax, results.step, results.count_wolves, color = :orange)
grassl = lines!(ax, results.step, results.count_grass, color = :green)
figure[1, 2] = Legend(figure, [sheepl, wolfl, grassl], ["Sheep", "Wolves", "Grass"])
figure

# Altering the input conditions, we now see a landscape where all three agents find an
# equilibrium.

Random.seed!(7756) # hide
model = initialize_model(
    n_wolves = 20,
    dims = (25, 25),
    Δenergy_sheep = 5,
    sheep_reproduce = 0.2,
    wolf_reproduce = 0.08,
)
results, _ = run!(model, agent_step!, n_steps; adata)

figure = Figure(resolution = (600, 400))
ax = figure[1, 1] = Axis(figure, xlabel = "Step", ylabel = "Population")
sheepl = lines!(ax, results.step, results.count_sheep, color = :blue)
wolfl = lines!(ax, results.step, results.count_wolves, color = :orange)
grassl = lines!(ax, results.step, results.count_grass, color = :green)
figure[1, 2] = Legend(figure, [sheepl, wolfl, grassl], ["Sheep", "Wolves", "Grass"])
figure

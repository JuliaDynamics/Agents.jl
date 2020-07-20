# # Daisyworld
# ![](daisyworld.gif)
#
# Study this example to learn about
# - Simple agent properties with complex model interactions
# - Rolling your own plots
# - Collecting data with the low-level data collection API
# - Simultaneously plotting and collecting data
# - Analyzing the behavior of a model
#
# ## Overview of Daisyworld
#
# This model explores the [Gaia hypothesis](https://en.wikipedia.org/wiki/Gaia_hypothesis),
# which considers the Earth as a single, self-regulating system including both living and
# non-living parts.
#
# Daisyworld is filled with black and white daisies.
# Their albedo's differ, with black daisies absorbing light and heat,
# warming the area around them; white daisies doing the opposite.
# Daisies can only reproduce within a certain temperature range, meaning too much
# (or too little) heat coming from the sun and/or surrounds will ultimately halt daisy
# propagation.
#
# When the climate is too cold it is necessary for the black daisies to propagate in order
# to raise the temperature, and vice versa -- when the climate is too warm, it is
# necessary for more white daisies to be produced in order to cool the temperature.
# The interplay of the living and non living aspects of this world manages to find an
# equilibrium over a wide range of parameter settings, although with enough external
# forcing, the daisies will not be able to regulate the temperature of the planet
# and eventually go extinct.

# ## Defining the agent types

# The agents here is not so complex. `Daisy` has three values (other than the required
# `id` and `pos` for an agent that lives on a [`GridSpace`](@ref). Each daisy has an `age`,
# confined later by a maximum age set by the user, a `breed` (either `:black` or `:white`)
# and an associated `albedo` value, again set by the user.
# `Land` represents the surface. We could make `Land` also have an albedo field, but
# in this world all surface has the same albedo and thus we make it a model parameter.

# Notice that the `Land` does not necessarily have to be an agent, and one could represent
# surface temperature via a matrix (parameter of the model). This is done in an older version,
# see file `examples/daisyworld_old.jl`. The old version has a slight performance advantage.
# However, the advantage of making the surface composed of
# agents is that visualization is simple and one can use the interactive applications.

using Agents, AgentsPlots, Plots
using Statistics: mean
using Random # hide
gr() # hide

mutable struct Daisy <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    breed::Symbol
    age::Int
    albedo::Float64 # 0-1 fraction
end

mutable struct Land <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    temperature::Float64
end

const DaisyWorld = ABM{Union{Daisy, Land}};

# ## World heating

# The surface temperature of the world is heated by its sun, but daisies growing upon it
# absorb or reflect the starlight -- altering the local temperature.

function update_surface_temperature!(node::Int, model::DaisyWorld)
    ids = get_node_contents(node, model)
    absorbed_luminosity = if length(ids) == 1 # no daisy
        ## Set luminosity via surface albedo
        (1 - model.surface_albedo) * model.solar_luminosity
    else
        ## Set luminosity via daisy albedo
        (1 - model[ids[2]].albedo) * model.solar_luminosity
    end
    ## We expect local heating to be 80 ᵒC for an absorbed luminosity of 1,
    ## approximately 30 for 0.5 and approximately -273 for 0.01.
    local_heating = absorbed_luminosity > 0 ? 72 * log(absorbed_luminosity) + 80 : 80
    ## Surface temperature is the average of the current temperature and local heating.
    T0 = model[ids[1]].temperature
    model[ids[1]].temperature = (T0 + local_heating) / 2
end

# In addition, temperature diffuses over time
function diffuse_temperature!(node::Int, model::DaisyWorld)
    ratio = get(model.properties, :ratio, 0.5) # diffusion ratio
    ids = space_neighbors(node, model)
    meantemp = sum(model[i].temperature for i in ids if model[i] isa Land)/8
    land = model[get_node_contents(node, model)[1]] # land at current node
    ## Each neighbor land patch is giving up 1/8 of the diffused
    ## amount to each of *its* neighbors
    land.temperature = (1 - ratio)*land.temperature + ratio*meantemp
end

# ## Daisy dynamics

# The final piece of the puzzle is the life-cycle of each daisy. This method defines an
# optimal temperature for growth. If the temperature gets too hot or too cold, daisies
# will not wish to propagate. So long as the temperature is favorable,
# daisies compete for land and attempt to spawn a new plant of their `breed` in locations
# close to them.

function propagate!(node::Int, model::DaisyWorld)
    ids = get_node_contents(node, model)
    if length(ids) > 1
        daisy = model[ids[2]]
        temperature = model[ids[1]].temperature
        ## Set optimum growth rate to 22.5 ᵒC, with bounds of [5, 40]
        seed_threshold = (0.1457 * temperature - 0.0032 * temperature^2) - 0.6443
        if rand() < seed_threshold
            ## Collect all adjacent cells that have no daisies
            empty_neighbors = Int[]
            neighbors = node_neighbors(node, model)
            for n in neighbors
                if length(get_node_contents(n, model)) == 1
                    push!(empty_neighbors, n)
                end
            end
            if !isempty(empty_neighbors)
                ## Seed a new daisy in one of those cells
                seeding_place = rand(empty_neighbors)
                add_agent!(seeding_place, model, daisy.breed, 0, daisy.albedo)
            end
        end
    end
end

# And if the daisies cross an age threshold, they die out.
# Death is controlled by the `agent_step` function
function agent_step!(agent::Daisy, model::DaisyWorld)
    agent.age += 1
    agent.age >= model.max_age && kill_agent!(agent, model)
end

# We also need to define a version for the `Land` instances
# (the dynamics of the `Land` are resolved at model level)
agent_step!(agent::Land, model::DaisyWorld) = nothing

# The model step function and agent step functions for Agents.jl to advance
# Daisyworld's dynamics. Since we have constructed a number of helper functions,
# these methods are quite straightforward.

function model_step!(model::DaisyWorld)
    for n in nodes(model)
        update_surface_temperature!(n, model)
        diffuse_temperature!(n, model)
        propagate!(n, model)
    end
    model.tick += 1
    solar_activity!(model)
end

# Notice that `solar_activity!` changes the incoming solar radiation over time,
# if the given "scenario" (a model parameter) is `:ramp`.
# The parameter `tick` of the model keeps track of time.

function solar_activity!(model::DaisyWorld)
    if model.scenario == :ramp
        if model.tick > 200 && model.tick <= 400
            model.solar_luminosity += 0.005
        end
        if model.tick > 500 && model.tick <= 750
            model.solar_luminosity -= 0.0025
        end
    end
end

# ## Initialising Daisyworld

# Here, we construct a function to initialize a Daisyworld. We need to know how many
# daisies of each type to seed the planet with and what their albedo's are. The albedo
# of the planet, as well as how intense the world's star tends to be. Alternatively
# we can provide a `scenario` flag, which alters the stars luminosity in different
# ways.
import StatsBase
import DrWatson: @dict

function daisyworld(;
        griddims = (30, 30),
        max_age = 25,
        init_white = 0.2, # % cover of the world surface of white breed
        init_black = 0.2, # % cover of the world surface of black breed
        albedo_white = 0.75,
        albedo_black = 0.25,
        surface_albedo = 0.4,
        solar_luminosity = 0.8, # initial luminosity
        scenario = :default,
    )

    space = GridSpace(griddims, moore = true, periodic = true)
    properties = @dict max_age surface_albedo solar_luminosity scenario
    properties[:tick] = 0
    ## create a scheduler that only schedules Daisies
    daisysched(model) = [id for id in keys(model) if model[id] isa Daisy]
    model = ABM(Union{Daisy, Land}, space;
        scheduler = daisysched, properties = properties, warn = false
    )

    ## fill model with `Land`: every grid cell has 1 land instance
    ## TODO: Fill space!
    for _ in 1:nv(space)
        a = Land(nextid(model), (1, 1), 0.0)
        add_agent_single!(a, model)
    end

    ## Populate with daisies: each cell has only one daisy (black or white)
    white_nodes = StatsBase.sample(1:nv(space), Int(init_white * nv(space)); replace = false)
    for n in white_nodes
        wd = Daisy(nextid(model), vertex2coord(n, space), :white, rand(0:max_age), albedo_white)
        add_agent_pos!(wd, model)
    end
    allowed = setdiff(1:nv(space), white_nodes)
    black_nodes = StatsBase.sample(allowed, Int(init_black * nv(space)); replace = false)
    for n in black_nodes
        wd = Daisy(nextid(model), vertex2coord(n, space), :black, rand(0:max_age), albedo_black)
        add_agent_pos!(wd, model)
    end

    return model
end

# ## Simple model run
# Lets run the model with constant solar isolation and visualize the result

cd(@__DIR__) #src
Random.seed!(165) # hide
model = daisyworld()

# To visualize we need to define the necessary functions for [`plotabm`](@ref).
# The daisies will obviously be black or white, but the land will have a color
# that reflects its temperature, with -50 darkest and 100 ᵒC brightest color

daisycolor(a::Daisy) = a.breed
const landcolor = cgrad(:thermal)
daisycolor(a::Land) = landcolor[(a.temperature+50)/150]

# And we plot daisies as circles, and land patches as squares
daisyshape(a::Daisy) = :circle
daisysize(a::Daisy) = 8
daisyshape(a::Land) = :square
daisysize(a::Land) = 13

# Notice that we want to ensure that the Land patches are always plotted first.
plotsched = by_type((Land, Daisy), false)

p = plotabm(model; ac = daisycolor, am = daisyshape, as = daisysize, scheduler = plotsched)
plot!(p; aspect_ratio = 1, size = (600, 600))

# And now we step the model a bit
step!(model, agent_step!, model_step!)

# We can see that this world achieves quasi-equilibrium, where one `breed` does not
# totally dominate the other.

sum(map(a -> [a.breed == :white, a.breed == :black], allagents(model)))

# ---

# Now we'll take a look at some of the complex dynamics this world can manifest.
# Some of these methods are, for the moment, not implemented in
# [AgentsPlots](https://github.com/JuliaDynamics/AgentsPlots.jl), although this does
# give us an opportunity to test out some of the new data collection features in
# Agents.jl v3.0. *Think you have a nice recipe for a plot that would help others?*
# [Send us a pull request](https://github.com/JuliaDynamics/AgentsPlots.jl/pulls)
# or [open an issue](https://github.com/JuliaDynamics/AgentsPlots.jl/issues).

# First, our fluctuating solar luminosity scenario.

model = daisyworld(scenario = :ramp)

# Then, let us initialize some dataframes for our model and agents. We are interested
# in the global surface temperature, the current solar luminosity and populations of
# each daisy breed. Notice that we made sure that `sum` has been given a default value
# since this model is using `kill_agent!` (see [`run!`](@ref) for more details).

global_temperature(model) = mean(model.temperature)
mdata = [global_temperature, :solar_luminosity]
model_df = init_model_dataframe(model, mdata)

white(agent) = agent.breed == :white
black(agent) = agent.breed == :black
total(v) = length(v) == 0 ? 0.0 : sum(v)
adata = [(white, total), (black, total)]
agent_df = init_agent_dataframe(model, adata)
nothing # hide

# Now we can evolve our model and observe what happens

anim = @animate for t in 1:900
    step!(model, agent_step!, model_step!, 1)
    collect_model_data!(model_df, model, mdata, t)
    collect_agent_data!(agent_df, model, adata, t)
    heatmap(
        1:model.space.dimensions[1],
        1:model.space.dimensions[2],
        transpose(reshape(model.temperature, model.space.dimensions));
        clims = (-50, 110),
        colorbar_title = "Temperature",
    )
    scatter!(
        [a.pos for a in allagents(model)];
        marker = (:circle, 5),
        markercolor = [a.breed for a in allagents(model)],
        label = :none,
        showaxis = false,
    )
end
gif(anim, "daisyworld.gif", fps = 10)

# Very interesting! But why is this all happening? Luckily we have collected some useful
# data, so now if we plot our different properties over the same time period, we can see
# how each of the values effect Daisyworld as a whole.

p1 = plot(model_df[!, :solar_luminosity], legend = false, ylabel = "Solar Luminosity")
p2 = plot(model_df[!, :global_temperature], legend = false, ylabel = "Global Temperature")
p3 = plot(
    [agent_df[!, aggname(white, total)], agent_df[!, aggname(black, total)]],
    legend = false,
    ylabel = "Population",
)
plot(p1, p2, p3, layout = (3, 1), size = (500, 800))

# We observe an initial period of low solar luminosity which favors a large population of
# black daisies. The population however is kept in check by competition from white daisies
# and a semi-stable global temperature regime is reached, fluctuating between ~32 and 41
# degrees.
#
# An increase in solar luminosity forces a population inversion, then a struggle for
# survival for the black daisies -- which ultimately leads to their extinction. At
# extremely high solar output the white daisies dominate the landscape, leading to a
# uniform surface temperature.
#
# Finally, as the sun fades back to normal levels, both the temperature and white daisy
# population struggle to find equilibrium. The counterbalancing force of the black daisies
# being absent, Daisyworld is plunged into a chaotic regime -- indicating the strong role
# biodiversity has to play in stabilizing climate.

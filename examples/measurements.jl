# # [Encapsulating uncertainty with Measurements.jl or MonteCarloMeasurements.jl](@id uncertainty)
#
# ## Uncertain numbers in Julia
#
# The Julia language and its multiple dispatch system make it straightforward
# to incorporate uncertainty in any quantity represented by real number(s).
# There are two packages in particular that provide such functionality,
# both of which can be integrated trivially with Agents.jl (due to multiple dispatch).
# These are:
# - [Measurements.jl](https://github.com/JuliaPhysics/Measurements.jl)
# - [MonteCarloMeasurements.jl](https://github.com/baggepinnen/MonteCarloMeasurements.jl)

# They both provide a numeric type that represents uncertainty in one way
# or the other. For example, let's assume we have two numbers that are normally distributed

xval = 1.0
yval = 5.0
σ = 0.25

# then

import Measurements
x = Measurements.measurement(xval, σ)
y = Measurements.measurement(yval, σ)
sqrt(x^2 - 2x*y + y^2)

# or

import MonteCarloMeasurements
using Distributions: Normal, Cosine # can use any distributions
x = MonteCarloMeasurements.Particles(100, Normal(xval, σ))
y = MonteCarloMeasurements.Particles(100, Normal(yval, σ))
sqrt(x^2 - 2x*y + y^2)

# For convience we will define two functions that will give the mean and std
# of an uncertain numeric type irrespectively of type used

meanval(x::Float64) = x
stdval(x::Float64) = 0.0 # no uncertainty for exact real number!

meanval(x::Measurements.Measurement) = Measurements.value(x)
stdval(x::Measurements.Measurement) = Measurements.uncertainty(x)

meanval(x::MonteCarloMeasurements.Particles) = MonteCarloMeasurements.pmean(x)
stdval(x::MonteCarloMeasurements.Particles) = MonteCarloMeasurements.pstd(x)

# ## Defining the Daisyworld model with uncertainty

# Here, we'll modify the [Daisyworld](https://juliadynamics.github.io/AgentsExampleZoo.jl/dev/examples/daisyworld/)
# model to incorporate uncertainty in the initial temperature of the planet
# as well as the albedo of the daisies.

# First, we define the daisy agent type as parameteric
using Agents

@agent struct Daisy{T}(GridAgent{2})
    breed::Symbol
    age::Int
    albedo::T
end

# The type parameter `T` will represent varius numeric types.
# Now we need to define the rules of the Daisyworld.
# There is practically at all in this step from the original Daisyworld example!
# We only need to change using a logarithm (not defined for negative numbers)
# and ensure that we are using the mean of an uncertain number in boolean operations,
# as it is otherwise umbiguous which number to use to make the Boolean decision.
# The rest of the functions do not
# care about us wanting to use this uncertainty-representing numeric type.
# This is one of the beauties of generic programming in Julia!

# We first define the individual daisy dynamics

function daisy_step!(agent::Daisy, model)
    agent.age += 1
    if agent.age ≥ model.max_age
        remove_agent!(agent, model)
        return
    end
    ## if daisy stays alive, it may propagate an offspring
    pos = agent.pos
    temperature = meanval(model.temperature[pos...]) # can't use uncertainty in Boolean operations
    seed_threshold = (0.1457 * temperature - 0.0032 * temperature^2) - 0.6443
    if rand(abmrng(model)) < seed_threshold
        empty_near_pos = random_nearby_position(pos, model, 1, npos -> isempty(npos, model))
        if !isnothing(empty_near_pos)
            add_agent!(empty_near_pos, model, agent.breed, 0, agent.albedo)
        end
    end
end

# and then the dynamics of the Daisyworld

function daisyworld_step!(model)
    for p in positions(model)
        update_surface_temperature!(p, model)
        diffuse_temperature!(p, model)
    end
end

function update_surface_temperature!(pos, model)
    if isempty(pos, model) # no daisy
        absorbed_luminosity = (1 - model.surface_albedo) * model.solar_luminosity
    else
        daisy = model[id_in_position(pos, model)]
        absorbed_luminosity = (1 - daisy.albedo) * model.solar_luminosity
    end
    ## Here we changed the rule to not use `log` because it isn't defined for negative numbers!
    ## We also need to somehow extract a number from the uncertain number, because boolean
    ## comparisons are not defined on uncertain numbers.
    local_heating = meanval(absorbed_luminosity) > 0 ? 72 *(2absorbed_luminosity - 1.8) + 80 : 80
    model.temperature[pos...] = (model.temperature[pos...] + local_heating) / 2
end

function diffuse_temperature!(pos, model)
    ratio = model.ratio # diffusion ratio
    npos = nearby_positions(pos, model)
    model.temperature[pos...] =
        (1 - ratio) * model.temperature[pos...] +
        sum(model.temperature[p...] for p in npos) * 0.125 * ratio
end

# Now as per usual in Agents.jl we will define a function that creates
# the daisyworld and populates it with some daisies.
# The starting temperature

using Random: Xoshiro
using StatsBase: sample

function daisyworld(;
        griddims = (30, 30),
        max_age = 25,
        init_white = 0.3, # % cover of the world surface of white breed
        init_black = 0.3, # % cover of the world surface of black breed
        albedo_white = 0.75,
        albedo_black = 0.25,
        surface_albedo = 0.4,
        solar_luminosity = 1.0,
        seed = 165,
        starting_temperature = 0.0,
    )

    rng = Xoshiro(seed)
    space = GridSpaceSingle(griddims)
    properties = (; # named tuple
        max_age, surface_albedo, solar_luminosity,
        ratio = 0.5, temperature = fill(starting_temperature, griddims)
    )

    T = typeof(albedo_black)
    model = StandardABM(Daisy{T}, space; properties, rng, agent_step! = daisy_step!, model_step! = daisyworld_step!)

    ## populate the model with random white daisies
    grid = collect(positions(model))
    L = length(grid)
    white_positions = sample(rng, grid, round(Int, init_white*L); replace = false)
    for wp in white_positions
        add_agent!(wp, model, :white, rand(abmrng(model), 0:max_age), albedo_white)
    end
    ## and black daisies
    possible_black = setdiff(grid, white_positions)
    black_positions = sample(rng, possible_black, Int(init_black*L); replace = false)
    for bp in black_positions
        add_agent!(bp, model, :black, rand(abmrng(model), 0:max_age), albedo_black)
    end

    for p in positions(model)
        update_surface_temperature!(p, model)
    end

    return model
end


# ## Running Daisyworld without uncertainty

# There isn't anything new here; we are doing the same as in the original Daisyworld example.
# Let's define a convenience plotting function first
using Statistics: mean
using CairoMakie

function run_plot_daisyworld(; steps = 500, kw...)

    abm = daisyworld(; kw...)

    function temp_mean(abm)
        T = abm.temperature
        return mean(meanval(t) for t in T)
    end
    function temp_std(abm)
        T = abm.temperature
        return mean(stdval(t) for t in T)
    end
    black_daisies(abm) = count(a -> a.breed == :black, allagents(abm))
    white_daisies(abm) = count(a -> a.breed == :white, allagents(abm))
    mdata = [temp_mean, temp_std, black_daisies, white_daisies]

    adf, mdf = run!(abm, steps; mdata)
    t = 0:steps

    ## plot daisy populations
    fig, ax = lines(t, mdf.black_daisies; color = "black", label = "black")
    lines!(ax, t, mdf.white_daisies; color = "gray", linestyle = :dash, label = "white")
    axislegend(ax)
    hidexdecorations!(ax, grid = false)
    ax.ylabel = "daisy populations"
    ntype = typeof(first(allagents(abm)).albedo)
    ax.title = "Numeric type: $(ntype)"
    ## plot planet temperature
    axt, = lines(fig[2, 1], t, mdf.temp_mean; color = "red")
    band!(axt, t, mdf.temp_mean .- mdf.temp_std, mdf.temp_mean .+ mdf.temp_std; color = ("red", 0.25))
    axt.ylabel = "temperature"
    axt.xlabel = "time"
    return fig
end

run_plot_daisyworld()

# Right, this looks great! As expected, there is no band plot shown in the temperature
# axis as there is no uncertainty yet. Let's change that!

# %% #src
# ## Running Daisyworld with uncertainty

# All we have to do to enable uncertainty is change the daisy albedos and starting
# temperature into numbers with uncertainty. This is as simple as changing three keywords:

run_plot_daisyworld(;
    starting_temperature = Measurements.measurement(0.0, 1.0),
    albedo_white = Measurements.measurement(0.75, 0.1),
    albedo_black = Measurements.measurement(0.25, 0.1),
)

# Well that's great! It also works with the other type of uncertainty:

run_plot_daisyworld(;
    starting_temperature = MonteCarloMeasurements.Particles(100, Normal(0.0, 1.0)),
    albedo_white = MonteCarloMeasurements.Particles(100, Normal(0.75, 0.2)),
    albedo_black = MonteCarloMeasurements.Particles(100, Cosine(0.25, 0.1)),
)

# We can see that:
#
# 1. The daisy populations do not change regardless of if we use uncertainty or not.
#    This is expected as the uncertainty itself does not actually decide any model dynamics.
# 2. The uncertainty in surface temperature does not increase over time.
using Random
import StatsBase
export Daisy, Land, DaisyWorld

mutable struct Daisy <: AbstractAgent
    id::Int
    pos::Dims{2}
    breed::Symbol
    age::Int
    albedo::Float64 # 0-1 fraction
end

mutable struct Land <: AbstractAgent
    id::Int
    pos::Dims{2}
    temperature::Float64
end

const DaisyWorld = ABM{<:GridSpace,Union{Daisy,Land}};

"""
``` julia
daisyworld(;
    griddims = (30, 30),
    max_age = 25,
    init_white = 0.2,
    init_black = 0.2,
    albedo_white = 0.75,
    albedo_black = 0.25,
    surface_albedo = 0.4,
    solar_change = 0.005,
    solar_luminosity = 1.0,
    scenario = :default,
    seed = 165
)
```
Same as in [Daisyworld](@ref).

To access the `Daisy` and `Land` types, simply call
``` julia
using Agents.Models: Daisy, Land
```
"""
function daisyworld(;
    griddims = (30, 30),
    max_age = 25,
    init_white = 0.2, # % cover of the world surface of white breed
    init_black = 0.2, # % cover of the world surface of black breed
    albedo_white = 0.75,
    albedo_black = 0.25,
    surface_albedo = 0.4,
    solar_change = 0.005,
    solar_luminosity = 1.0, # initial luminosity
    scenario = :default,
    seed = 165,
)

    rng = MersenneTwister(seed)
    space = GridSpace(griddims)
    properties = Dict(
        :max_age => max_age,
        :surface_albedo => surface_albedo,
        :solar_luminosity => solar_luminosity,
        :solar_change => solar_change,
        :scenario => scenario,
        :tick => 0,
    )

    model = ABM(
        Union{Daisy,Land},
        space;
        scheduler = daisysched,
        properties,
        rng,
        warn = false,
    )

    ## fill model with `Land`: every grid position has 1 land instance
    fill_space!(Land, model, 0.0) # zero starting temperature

    ## Populate with daisies: each position has only one daisy (black or white)
    grid = collect(positions(model))
    num_positions = prod(griddims)
    white_positions =
        StatsBase.sample(grid, Int(init_white * num_positions); replace = false)
    for wp in white_positions
        wd = Daisy(nextid(model), wp, :white, rand(model.rng, 0:max_age), albedo_white)
        add_agent_pos!(wd, model)
    end
    allowed = setdiff(grid, white_positions)
    black_positions =
        StatsBase.sample(allowed, Int(init_black * num_positions); replace = false)
    for bp in black_positions
        wd = Daisy(nextid(model), bp, :black, rand(model.rng, 0:max_age), albedo_black)
        add_agent_pos!(wd, model)
    end

    return model, daisyworld_agent_step!, daisyworld_model_step!
end

## create a scheduler that only schedules Daisies
daisysched(model) = [a.id for a in allagents(model) if a isa Daisy]

function update_surface_temperature!(pos::Dims{2}, model::DaisyWorld)
    ids = ids_in_position(pos, model)
    ## All grid positions have at least one agent (the land)
    absorbed_luminosity = if length(ids) == 1
        ## Set luminosity via surface albedo
        (1 - model.surface_albedo) * model.solar_luminosity
    else
        ## more than 1 agents: daisy exists
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

function diffuse_temperature!(pos::Dims{2}, model::DaisyWorld)
    ratio = get(model.properties, :ratio, 0.5) # diffusion ratio
    ids = nearby_ids(pos, model)
    meantemp = sum(model[i].temperature for i in ids if model[i] isa Land) / 8
    land = model[ids_in_position(pos, model)[1]] # land at current position
    ## Each neighbor land patch is giving up 1/8 of the diffused
    ## amount to each of *its* neighbors
    land.temperature = (1 - ratio) * land.temperature + ratio * meantemp
end

function propagate!(pos::Dims{2}, model::DaisyWorld)
    ids = ids_in_position(pos, model)
    if length(ids) > 1
        daisy = model[ids[2]]
        temperature = model[ids[1]].temperature
        ## Set optimum growth rate to 22.5 ᵒC, with bounds of [5, 40]
        seed_threshold = (0.1457 * temperature - 0.0032 * temperature^2) - 0.6443
        if rand(model.rng) < seed_threshold
            ## Collect all adjacent position that have no daisies
            empty_neighbors = Tuple{Int,Int}[]
            neighbors = nearby_positions(pos, model)
            for n in neighbors
                if length(ids_in_position(n, model)) == 1
                    push!(empty_neighbors, n)
                end
            end
            if !isempty(empty_neighbors)
                ## Seed a new daisy in one of those position
                seeding_place = rand(model.rng, empty_neighbors)
                a = Daisy(nextid(model), seeding_place, daisy.breed, 0, daisy.albedo)
                add_agent_pos!(a, model)
            end
        end
    end
end

function daisyworld_agent_step!(agent::Daisy, model::DaisyWorld)
    agent.age += 1
    agent.age >= model.max_age && kill_agent!(agent, model)
end

daisyworld_agent_step!(agent::Land, model::DaisyWorld) = nothing

function daisyworld_model_step!(model)
    for p in positions(model)
        update_surface_temperature!(p, model)
        diffuse_temperature!(p, model)
        propagate!(p, model)
    end
    model.tick += 1
    solar_activity!(model)
end

function solar_activity!(model::DaisyWorld)
    if model.scenario == :ramp
        if model.tick > 200 && model.tick <= 400
            model.solar_luminosity += model.solar_change
        end
        if model.tick > 500 && model.tick <= 750
            model.solar_luminosity -= model.solar_change / 2
        end
    elseif model.scenario == :change
        model.solar_luminosity += model.solar_change
    end
end

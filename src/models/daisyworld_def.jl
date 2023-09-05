using Agents
import StatsBase
using Random

@agent Daisy GridAgent{2} begin
    breed::Symbol
    age::Int
    albedo::Float64 # 0-1 fraction
end

DaisyWorld = ABM{<:GridSpaceSingle, Daisy}

function update_surface_temperature!(pos, model::DaisyWorld)
    absorbed_luminosity = if isempty(pos, model) # no daisy
        (1 - model.surface_albedo) * model.solar_luminosity
    else
        daisy = model[id_in_position(pos, model)]
        (1 - daisy.albedo) * model.solar_luminosity
    end
    local_heating = absorbed_luminosity > 0 ? 72 * log(absorbed_luminosity) + 80 : 80
    model.temperature[pos...] = (model.temperature[pos...] + local_heating) / 2
end

function diffuse_temperature!(pos, model::DaisyWorld)
    ratio = model.ratio # diffusion ratio
    npos = nearby_positions(pos, model)
    model.temperature[pos...] =
        (1 - ratio) * model.temperature[pos...] +
        sum(model.temperature[p...] for p in npos) * 0.125 * ratio
end

function propagate!(pos, model::DaisyWorld)
    isempty(pos, model) && return
    daisy = model[id_in_position(pos, model)]
    temperature = model.temperature[pos...]
    seed_threshold = (0.1457 * temperature - 0.0032 * temperature^2) - 0.6443
    if rand(abmrng(model)) < seed_threshold
        empty_near_pos = random_nearby_position(pos, model, 1, npos -> isempty(npos, model))
        if !isnothing(empty_near_pos)
            add_agent!(empty_near_pos, model, daisy.breed, 0, daisy.albedo)
        end
    end
end

function daisy_step!(agent::Daisy, model::DaisyWorld)
    agent.age += 1
    agent.age ≥ model.max_age && remove_agent!(agent, model)
end

function daisyworld_step!(model)
    for p in positions(model)
        update_surface_temperature!(p, model)
        diffuse_temperature!(p, model)
        propagate!(p, model)
    end
    model.tick = model.tick + 1
    solar_activity!(model)
end

function solar_activity!(model::DaisyWorld)
    if model.scenario == :ramp
        if model.tick > 200 && model.tick ≤ 400
            model.solar_luminosity += model.solar_change
        end
        if model.tick > 500 && model.tick ≤ 750
            model.solar_luminosity -= model.solar_change / 2
        end
    elseif model.scenario == :change
        model.solar_luminosity += model.solar_change
    end
end

using Random

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
    space = GridSpaceSingle(griddims)
    properties = (;max_age, surface_albedo, solar_luminosity, solar_change, scenario,
        tick = 0, ratio = 0.5, temperature = zeros(griddims)
    )
    properties = Dict(k=>v for (k,v) in pairs(properties))

    model = ABM(Daisy, space; properties, rng)

    grid = collect(positions(model))
    num_positions = prod(griddims)
    white_positions =
        StatsBase.sample(grid, Int(init_white * num_positions); replace = false)
    for wp in white_positions
        wd = Daisy(nextid(model), wp, :white, rand(abmrng(model), 0:max_age), albedo_white)
        add_agent_pos!(wd, model)
    end
    allowed = setdiff(grid, white_positions)
    black_positions =
        StatsBase.sample(allowed, Int(init_black * num_positions); replace = false)
    for bp in black_positions
        wd = Daisy(nextid(model), bp, :black, rand(abmrng(model), 0:max_age), albedo_black)
        add_agent_pos!(wd, model)
    end

    for p in positions(model)
        update_surface_temperature!(p, model)
    end

    return model, daisy_step!, daisyworld_step!
end

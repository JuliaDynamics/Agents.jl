using Random
import StatsBase
import DrWatson: @dict

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

""" julia
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
Same as in [Daisyworld](@ref).
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
        seed = 165
    )

    Random.seed!(seed)
    space = GridSpace(griddims, moore = true, periodic = true)
    properties = @dict max_age surface_albedo solar_luminosity solar_change scenario
    properties[:tick] = 0
    ## create a scheduler that only schedules Daisies
    daisysched(model) = [a.id for a in allagents(model) if a isa Daisy]
    model = ABM(Union{Daisy, Land}, space;
        scheduler = daisysched, properties = properties, warn = false
    )

    ## fill model with `Land`: every grid cell has 1 land instance
    fill_space!(Land, model, 0.0) # zero starting temperature

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

    return model, agent_step!, model_step!
end

function update_surface_temperature!(node::Int, model::DaisyWorld)
    ids = get_node_contents(node, model)
    ## All grid points have at least one agent (the land)
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

function diffuse_temperature!(node::Int, model::DaisyWorld)
    ratio = get(model.properties, :ratio, 0.5) # diffusion ratio
    ids = space_neighbors(node, model)
    meantemp = sum(model[i].temperature for i in ids if model[i] isa Land)/8
    land = model[get_node_contents(node, model)[1]] # land at current node
    ## Each neighbor land patch is giving up 1/8 of the diffused
    ## amount to each of *its* neighbors
    land.temperature = (1 - ratio)*land.temperature + ratio*meantemp
end

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
                seeding_place = vertex2coord(rand(empty_neighbors), model)
                a = Daisy(nextid(model), seeding_place, daisy.breed, 0, daisy.albedo)
                add_agent_pos!(a, model)
            end
        end
    end
end

function agent_step!(agent::Daisy, model::DaisyWorld)
    agent.age += 1
    agent.age >= model.max_age && kill_agent!(agent, model)
end

agent_step!(agent::Land, model::DaisyWorld) = nothing

function model_step!(model)
    for n in nodes(model)
        update_surface_temperature!(n, model)
        diffuse_temperature!(n, model)
        propagate!(n, model)
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
            model.solar_luminosity -= model.solar_change/2
        end
    elseif model.scenario == :change
        model.solar_luminosity += model.solar_change
    end
end

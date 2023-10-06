using Agents, CairoMakie

# used
model_names = [
    "Daisyworld",
    "Flocking",
    "Mountain runners",
    "Growing bacteria",
    "Forest fire",
    "Ant colony",
    "Zombie outbreak",
    "Fractal growth",
    "Social distancing",
]
steps_per_frame = [
    1,
    2,
    5,
    100,
    1,
    2,
    1,
    20,
    3,
]
models = Any[nothing for _ in 1:9]
rules = Any[nothing for _ in 1:9]
unikwargs = (add_colorbar = false, add_controls = false, adjust_aspect = false,)

fig = Figure(resolution = (1200, 1220))
axs = Axis[]
for (i, c) in enumerate(CartesianIndices((3,3)))
    ax = Axis(fig[c.I...]; title = model_names[i])
    hidedecorations!(ax)
    push!(axs, ax)
end

Label(fig[0, :], "Agents.jl zoo of examples";
    tellheight = true, tellwidth = false,
    valign = :bottom, padding = (0,0,0,0),
    font = "TeX Gyre Heros Bold",
    height = 20, fontsize = 30,
)

# DaisyWorld
daisypath = joinpath(pathof(Agents), "../../", "ext", "src", "daisyworld_def.jl")
include(daisypath)
daisy_model, daisy_step!, daisyworld_step! = daisyworld(;
    solar_luminosity = 1.0, solar_change = 0.0, scenario = :change
)
daisycolor(a::Daisy) = a.breed # agent color
as = 15    # agent size
am = '✿'  # agent marker
scatterkwargs = (strokewidth = 1.0,) # add stroke around each agent
heatarray = :temperature
heatkwargs = (colorrange = (-20, 60), colormap = :thermal)
plotkwargs = (;
    ac = daisycolor, as, am,
    scatterkwargs = (strokewidth = 0.5,),
    heatarray, heatkwargs, unikwargs...,
)

daisy_obs = abmplot!(axs[1], daisy_model;
agent_step! = daisy_step!, model_step! = daisyworld_step!,
plotkwargs..., unikwargs...,)
models[1] = daisy_obs

# Flocking
@agent struct Bird(ContinuousAgent{2,Float64})
    speed::Float64
    cohere_factor::Float64
    separation::Float64
    separate_factor::Float64
    match_factor::Float64
    visual_distance::Float64
end

function flocking_model(;
    n_birds = 100,
    speed = 2.0,
    cohere_factor = 0.4,
    separation = 4.0,
    separate_factor = 0.25,
    match_factor = 0.02,
    visual_distance = 5.0,
    extent = (100, 100),
    seed = 42,
)
    space2d = ContinuousSpace(extent; spacing = visual_distance/1.5)
    rng = Random.MersenneTwister(seed)

    model = StandardABM(Bird, space2d; rng, scheduler = Schedulers.Randomly())
    for _ in 1:n_birds
        vel = rand(abmrng(model), SVector{2}) * 2 .- 1
        add_agent!(
            model,
            vel,
            speed,
            cohere_factor,
            separation,
            separate_factor,
            match_factor,
            visual_distance,
        )
    end
    return model
end

function bird_step!(bird, model)
    neighbor_ids = nearby_ids(bird, model, bird.visual_distance)
    N = 0
    match = separate = cohere = (0.0, 0.0)
    for id in neighbor_ids
        N += 1
        neighbor = model[id].pos
        heading = neighbor .- bird.pos

        cohere = cohere .+ heading
        if euclidean_distance(bird.pos, neighbor, model) < bird.separation
            separate = separate .- heading
        end
        match = match .+ model[id].vel
    end
    N = max(N, 1)
    cohere = cohere ./ N .* bird.cohere_factor
    separate = separate ./ N .* bird.separate_factor
    match = match ./ N .* bird.match_factor
    bird.vel = (bird.vel .+ cohere .+ separate .+ match) ./ 2
    bird.vel = bird.vel ./ norm(bird.vel)
    move_agent!(bird, model, bird.speed)
end
const bird_polygon = Makie.Polygon(Point2f[(-1, -1), (2, 0), (-1, 1)])
function bird_marker(b::Bird)
    φ = atan(b.vel[2], b.vel[1]) #+ π/2 + π
    rotate_polygon(bird_polygon, φ)
end

flock_model = flocking_model()
flock_obs = abmplot!(axs[2], flock_model;
    agent_step! = bird_step!,
    am = bird_marker,  unikwargs...,
)
models[2] = flock_obs

# Zombie outbreak
using OSMMakie
default_colors = OSMMakie.WAYTYPECOLORS
default_colors["primary"] = colorant"#a1777f"
default_colors["secondary"] = colorant"#a18f78"
default_colors["tertiary"] = colorant"#b3b381"

@agent struct Zombie(OSMAgent)
    infected::Bool
    speed::Float64
end
function initialise_zombies(; seed = 1234)
    map_path = OSM.test_map()
    properties = Dict(:dt => 1 / 60)
    model = StandardABM(
        Zombie,
        OpenStreetMapSpace(map_path);
        properties = properties,
        rng = Random.MersenneTwister(seed)
    )

    for id in 1:100
        start = random_position(model) # At an intersection
        speed = rand(abmrng(model)) * 5.0 + 2.0 # Random speed from 2-7kmph
        human = add_agent!(start, Zombie, model, false, speed)
        OSM.plan_random_route!(human, model; limit = 50) # try 50 times to find a random route
    end
    start = OSM.nearest_road((9.9351811, 51.5328328), model)
    finish = OSM.nearest_node((9.945125635913511, 51.530876112711745), model)

    speed = rand(abmrng(model)) * 5.0 + 2.0 # Random speed from 2-7kmph
    zombie = add_agent!(start, model, true, speed)
    plan_route!(zombie, finish, model)
    return model
end
function zombie_step!(agent, model)
    distance_left = move_along_route!(agent, model, agent.speed * model.dt)
    if is_stationary(agent, model) && rand(abmrng(model)) < 0.1
        OSM.plan_random_route!(agent, model; limit = 50)
        move_along_route!(agent, model, distance_left)
    end
    if agent.infected
        map(i -> model[i].infected = true, nearby_ids(agent, model, 0.01))
    end
    return
end

zombie_color(agent) = agent.infected ? :green : :black
zombie_size(agent) = agent.infected ? 15 : 10
zombies = initialise_zombies()
zombies_obs = abmplot!(axs[7], zombies;
    ac = zombie_color, as = zombie_size, unikwargs...,
    scatterkwargs = (strokecolor = :white, strokewidth = 1),
    agent_step! = zombie_step!,

)
models[7] = zombies_obs

# Growing bacteria
using Agents, LinearAlgebra
using Random # hide
@agent struct SimpleCell(ContinuousAgent{2,Float64})
    length::Float64
    orientation::Float64
    growthprog::Float64
    growthrate::Float64

    ## node positions/forces
    p1::NTuple{2,Float64}
    p2::NTuple{2,Float64}
    f1::NTuple{2,Float64}
    f2::NTuple{2,Float64}
end
function SimpleCell(id, pos, l, φ, g, γ)
    a = SimpleCell(id, pos, l, φ, g, γ, (0.0, 0.0), (0.0, 0.0), (0.0, 0.0), (0.0, 0.0))
    update_nodes!(a)
    return a
end

function update_nodes!(a::SimpleCell)
    offset = 0.5 * a.length .* unitvector(a.orientation)
    a.p1 = a.pos .+ offset
    a.p2 = a.pos .- offset
end
unitvector(φ) = reverse(sincos(φ))
cross2D(a, b) = a[1] * b[2] - a[2] * b[1]
function bacteria_model_step!(model)
    for a in allagents(model)
        if a.growthprog ≥ 1
            ## When a cell has matured, it divides into two daughter cells on the
            ## positions of its nodes.
            add_agent!(a.p1, model, 0.0, a.orientation, 0.0, 0.1 * rand(abmrng(model)) + 0.05)
            add_agent!(a.p2, model, 0.0, a.orientation, 0.0, 0.1 * rand(abmrng(model)) + 0.05)
            remove_agent!(a, model)
        else
            ## The rest length of the internal spring grows with time. This causes
            ## the nodes to physically separate.
            uv = unitvector(a.orientation)
            internalforce = model.hardness * (a.length - a.growthprog) .* uv
            a.f1 = -1 .* internalforce
            a.f2 = internalforce
        end
    end
    ## Bacteria can interact with more than on other cell at the same time, therefore,
    ## we need to specify the option `:all` in `interacting_pairs`
    for (a1, a2) in interacting_pairs(model, 2.0, :all)
        interact!(a1, a2, model)
    end
end
function bacterium_step!(agent::SimpleCell, model::ABM)
    fsym, compression, torque = transform_forces(agent)
    direction =  model.dt * model.mobility .* fsym
    walk!(agent, direction, model)
    agent.length += model.dt * model.mobility .* compression
    agent.orientation += model.dt * model.mobility .* torque
    agent.growthprog += model.dt * agent.growthrate
    update_nodes!(agent)
    return agent.pos
end
function interact!(a1::SimpleCell, a2::SimpleCell, model)
    n11 = noderepulsion(a1.p1, a2.p1, model)
    n12 = noderepulsion(a1.p1, a2.p2, model)
    n21 = noderepulsion(a1.p2, a2.p1, model)
    n22 = noderepulsion(a1.p2, a2.p2, model)
    a1.f1 = @. a1.f1 + (n11 + n12)
    a1.f2 = @. a1.f2 + (n21 + n22)
    a2.f1 = @. a2.f1 - (n11 + n21)
    a2.f2 = @. a2.f2 - (n12 + n22)
end

function noderepulsion(p1::NTuple{2,Float64}, p2::NTuple{2,Float64}, model::ABM)
    delta = p1 .- p2
    distance = norm(delta)
    if distance ≤ 1
        uv = delta ./ distance
        return (model.hardness * (1 - distance)) .* uv
    end
    return (0, 0)
end

function transform_forces(agent::SimpleCell)
    ## symmetric forces (CM movement)
    fsym = agent.f1 .+ agent.f2
    ## antisymmetric forces (compression, torque)
    fasym = agent.f1 .- agent.f2
    uv = unitvector(agent.orientation)
    compression = dot(uv, fasym)
    torque = 0.5 * cross2D(uv, fasym)
    return fsym, compression, torque
end

bacteria_model = StandardABM(
    SimpleCell,
    ContinuousSpace((14, 9); spacing = 1.0, periodic = false);
    properties = Dict(:dt => 0.005, :hardness => 1e2, :mobility => 1.0),
    rng = MersenneTwister(1680)
)

add_agent!((6.5, 4.0), bacteria_model, 0.0, 0.3, 0.0, 0.1)
add_agent!((7.5, 4.0), bacteria_model, 0.0, 0.0, 0.0, 0.1)

function cassini_oval(agent)
    t = LinRange(0, 2π, 50)
    a = agent.growthprog
    b = 1
    m = @. 2 * sqrt((b^4 - a^4) + a^4 * cos(2 * t)^2) + 2 * a^2 * cos(2 * t)
    C = sqrt.(m / 2)

    x = C .* cos.(t)
    y = C .* sin.(t)

    uv = reverse(sincos(agent.orientation))
    θ = atan(uv[2], uv[1])
    R = [cos(θ) -sin(θ); sin(θ) cos(θ)]

    bacteria = R * permutedims([x y])
    coords = [Point2f(x, y) for (x, y) in zip(bacteria[1, :], bacteria[2, :])]
    scale_polygon(Makie.Polygon(coords), 0.5)
end
bacteria_color(b) = RGBf(b.id * 3.14 % 1, 0.2, 0.2)

bacteria_obs = abmplot!(axs[4], bacteria_model;
    am = cassini_oval, ac = bacteria_color, unikwargs...,
    agent_step! = bacterium_step!, model_step! = bacteria_model_step!,
)
models[4] = bacteria_obs

# Mountain runners
using Agents.Pathfinding
@agent struct Runner(GridAgent{2})
end
using FileIO

function initialize_runners(map_url; goal = (128, 409), seed = 88)
    heightmap = floor.(Int, convert.(Float64, load(download(map_url))) * 255)
    space = GridSpace(size(heightmap); periodic = false)
    pathfinder = AStar(space; cost_metric = PenaltyMap(heightmap, MaxDistance{2}()))
    model = StandardABM(
        Runner,
        space;
        rng = MersenneTwister(seed),
        properties = Dict(:goal => goal, :pathfinder => pathfinder)
    )
    for _ in 1:10
        runner = add_agent!((rand(abmrng(model), 100:350), rand(abmrng(model), 50:200)), model)
        plan_route!(runner, goal, model.pathfinder)
    end
    return model
end
runner_step!(agent, model) = move_along_route!(agent, model, model.pathfinder)

map_url =
    "https://raw.githubusercontent.com/JuliaDynamics/" *
    "JuliaDynamics/master/videos/agents/runners_heightmap.jpg"
runners_model = initialize_runners(map_url)

runners_preplot!(ax, model) = scatter!(ax, model.goal; color = (:red, 50), marker = 'x')

plotkw = (
    figurekwargs = (resolution = (700, 700),),
    ac = :black,
    as = 8,
    unikwargs...,
    scatterkwargs = (strokecolor = :white, strokewidth = 2),
    heatarray = model -> penaltymap(model.pathfinder),
    heatkwargs = (colormap = :terrain,),
    static_preplot! = runners_preplot!,
)

runners_obs = abmplot!(axs[3], runners_model;
    plotkw..., unikwargs...,
    agent_step! = runner_step!,
)
models[3] = runners_obs

# Forest fire
function forest_fire(; density = 0.7, griddims = (100, 100), seed = 2)
    space = GridSpaceSingle(griddims; periodic = false, metric = :manhattan)
    rng = Random.MersenneTwister(seed)
    ## The `trees` field is coded such that
    ## Empty = 0, Green = 1, Burning = 2, Burnt = 3
    forest = StandardABM(GridAgent{2}, space; rng, properties = (trees = zeros(Int, griddims),))
    for I in CartesianIndices(forest.trees)
        if rand(abmrng(forest)) < density
            ## Set the trees at the left edge on fire
            forest.trees[I] = I[1] == 1 ? 2 : 1
        end
    end
    return forest
end
function forest_step!(forest)
    ## Find trees that are burning (coded as 2)
    for I in findall(isequal(2), forest.trees)
        for idx in nearby_positions(I.I, forest)
            ## If a neighbor is Green (1), set it on fire (2)
            if forest.trees[idx...] == 1
                forest.trees[idx...] = 2
            end
        end
        ## Finally, any burning tree is burnt out (2)
        forest.trees[I] = 3
    end
end
forest_model = forest_fire()
forestkwargs = (
    unikwargs...,
    heatarray = :trees,
    heatkwargs = (
        colorrange = (0, 3),
        colormap = cgrad([:white, :green, :red, :darkred]; categorical = true),
    ),
)

forest_obs = abmplot!(axs[5], forest_model;
    forestkwargs..., unikwargs..., model_step! = forest_step!,
)

models[5] = forest_obs

# Ants
@agent struct Ant(GridAgent{2})
    has_food::Bool
    facing_direction::Int
    food_collected::Int
    food_collected_once::Bool
end
AntWorld = ABM{<:GridSpace, Ant}
const adjacent_dict = Dict(
    1 => (0, -1), # S
    2 => (1, -1), # SE
    3 => (1, 0), # E
    4 => (1, 1), # NE
    5 => (0, 1), # N
    6 => (-1, 1), # NW
    7 => (-1, 0), # W
    8 => (-1, -1), # SW
)
const number_directions = length(adjacent_dict)
mutable struct AntWorldProperties
    pheremone_trails::Matrix
    food_amounts::Matrix
    nest_locations::Matrix
    food_source_number::Matrix
    food_collected::Int
    diffusion_rate::Int
    tick::Int
    x_dimension::Int
    y_dimension::Int
    nest_size::Int
    evaporation_rate::Int
    pheremone_amount::Int
    spread_pheremone::Bool
    pheremone_floor::Int
    pheremone_ceiling::Int
end
function initialize_antworld(;number_ants::Int = 125, dimensions::Tuple = (70, 70), diffusion_rate::Int = 50, food_size::Int = 7, random_seed::Int = 2954, nest_size::Int = 5, evaporation_rate::Int = 10, pheremone_amount::Int = 60, spread_pheremone::Bool = false, pheremone_floor::Int = 5, pheremone_ceiling::Int = 100)
    rng = Random.Xoshiro(random_seed)

    furthest_distance = sqrt(dimensions[1] ^ 2 + dimensions[2] ^ 2)

    x_center = dimensions[1] / 2
    y_center = dimensions[2] / 2

    nest_locations = zeros(Float32, dimensions)
    pheremone_trails = zeros(Float32, dimensions)

    food_amounts = zeros(dimensions)
    food_source_number = zeros(dimensions)

    food_center_1 = (round(Int, x_center + 0.6 * x_center), round(Int, y_center))
    food_center_2 = (round(Int, 0.4 * x_center), round(Int, 0.4 * y_center))
    food_center_3 = (round(Int, 0.2 * x_center), round(Int, y_center + 0.8 * y_center))

    food_collected = 0

    for x_val in 1:dimensions[1]
        for y_val in 1:dimensions[2]
            nest_locations[x_val, y_val] = ((furthest_distance - sqrt((x_val - x_center) ^ 2 + (y_val - y_center) ^ 2)) / furthest_distance) * 100
            food_1 = (sqrt((x_val - food_center_1[1]) ^ 2 + (y_val - food_center_1[2]) ^ 2)) < food_size
            food_2 = (sqrt((x_val - food_center_2[1]) ^ 2 + (y_val - food_center_2[2]) ^ 2)) < food_size
            food_3 = (sqrt((x_val - food_center_3[1]) ^ 2 + (y_val - food_center_3[2]) ^ 2)) < food_size
            food_amounts[x_val, y_val] = food_1 || food_2 || food_3 ? rand(rng, [1, 2]) : 0
            if food_1
                food_source_number[x_val, y_val] = 1
            elseif food_2
                food_source_number[x_val, y_val] = 2
            elseif food_3
                food_source_number[x_val, y_val] = 3
            end
        end
    end

    properties = AntWorldProperties(
        pheremone_trails,
        food_amounts,
        nest_locations,
        food_source_number,
        food_collected,
        diffusion_rate,
        0,
        dimensions[1],
        dimensions[2],
        nest_size,
        evaporation_rate,
        pheremone_amount,
        spread_pheremone,
        pheremone_floor,
        pheremone_ceiling
        )

    model = UnremovableABM(
        Ant,
        GridSpace(dimensions, periodic = false);
        properties,
        rng,
        scheduler = Schedulers.Randomly()
    )

    for n in 1:number_ants
        add_agent!((x_center, y_center), Ant, model, false, rand(abmrng(model), range(1, 8)), 0, false)
    end
    return model
end
function detect_change_direction(agent::Ant, model_layer::Matrix)
    x_dimension = size(model_layer)[1]
    y_dimension = size(model_layer)[2]
    left_pos = adjacent_dict[mod1(agent.facing_direction - 1, number_directions)]
    right_pos = adjacent_dict[mod1(agent.facing_direction + 1, number_directions)]

    scent_ahead = model_layer[mod1(agent.pos[1] + adjacent_dict[agent.facing_direction][1], x_dimension),
        mod1(agent.pos[2] + adjacent_dict[agent.facing_direction][2], y_dimension)]
    scent_left = model_layer[mod1(agent.pos[1] + left_pos[1], x_dimension),
        mod1(agent.pos[2] + left_pos[2], y_dimension)]
    scent_right = model_layer[mod1(agent.pos[1] + right_pos[1], x_dimension),
        mod1(agent.pos[2] + right_pos[2], y_dimension)]

    if (scent_right > scent_ahead) || (scent_left > scent_ahead)
        if scent_right > scent_left
            agent.facing_direction = mod1(agent.facing_direction + 1, number_directions)
        else
            agent.facing_direction =  mod1(agent.facing_direction - 1, number_directions)
        end
    end
end
function wiggle(agent::Ant, model::AntWorld)
    direction = rand(abmrng(model), [0, rand(abmrng(model), [-1, 1])])
    agent.facing_direction = mod1(agent.facing_direction + direction, number_directions)
end
function apply_pheremone(agent::Ant, model::AntWorld; pheremone_val::Int = 60, spread_pheremone::Bool = false)
    model.pheremone_trails[agent.pos...] += pheremone_val
    model.pheremone_trails[agent.pos...]  = model.pheremone_trails[agent.pos...] ≥ model.pheremone_floor ? model.pheremone_trails[agent.pos...] : 0

    if spread_pheremone
        left_pos = adjacent_dict[mod1(agent.facing_direction - 2, number_directions)]
        right_pos = adjacent_dict[mod1(agent.facing_direction + 2, number_directions)]

        model.pheremone_trails[mod1(agent.pos[1] + left_pos[1], model.x_dimension),
            mod1(agent.pos[2] + left_pos[2], model.y_dimension)] += (pheremone_val / 2)
        model.pheremone_trails[mod1(agent.pos[1] + right_pos[1], model.x_dimension),
            mod1(agent.pos[2] + right_pos[2], model.y_dimension)] += (pheremone_val / 2)
    end
end
function diffuse(model_layer::Matrix, diffusion_rate::Int)
    x_dimension = size(model_layer)[1]
    y_dimension = size(model_layer)[2]

    for x_val in 1:x_dimension
        for y_val in 1:y_dimension
            sum_for_adjacent = model_layer[x_val, y_val] * (diffusion_rate / 100) / number_directions
            for (_, i) in adjacent_dict
                model_layer[mod1(x_val + i[1], x_dimension), mod1(y_val + i[2], y_dimension)] += sum_for_adjacent
            end
            model_layer[x_val, y_val] *= ((100 - diffusion_rate) / 100)
        end
    end
end
turn_around(agent) = agent.facing_direction = mod1(agent.facing_direction + number_directions / 2, number_directions)

function ant_step!(agent::Ant, model::AntWorld)
    if agent.has_food
        if model.nest_locations[agent.pos...] > 100 - model.nest_size
            @debug "$(agent.n) arrived at nest with food"
            agent.food_collected += 1
            agent.food_collected_once = true
            model.food_collected += 1
            agent.has_food = false
            turn_around(agent)
        else
            detect_change_direction(agent, model.nest_locations)
        end
        apply_pheremone(agent, model, pheremone_val = model.pheremone_amount)
    else
        if model.food_amounts[agent.pos...] > 0
            agent.has_food = true
            model.food_amounts[agent.pos...] -= 1
            apply_pheremone(agent, model, pheremone_val = model.pheremone_amount)
            turn_around(agent)
        elseif model.pheremone_trails[agent.pos...] > model.pheremone_floor
            detect_change_direction(agent, model.pheremone_trails)
        end
    end
    wiggle(agent, model)
    move_agent!(agent, (mod1(agent.pos[1] + adjacent_dict[agent.facing_direction][1], model.x_dimension), mod1(agent.pos[2] + adjacent_dict[agent.facing_direction][2], model.y_dimension)), model)
end
function antworld_step!(model::AntWorld)
    diffuse(model.pheremone_trails, model.diffusion_rate)
    map!((x) -> x ≥ model.pheremone_floor ? x * (100 - model.evaporation_rate) / 100 : 0.0, model.pheremone_trails, model.pheremone_trails)
    model.tick += 1
end

function antworld_heatmap(model::AntWorld)
    heatmap = zeros((model.x_dimension, model.y_dimension))
    for x_val in 1:model.x_dimension
        for y_val in 1:model.y_dimension
            if model.nest_locations[x_val, y_val] > 100 - model.nest_size
                heatmap[x_val, y_val] = 150
            elseif model.food_amounts[x_val, y_val] > 0
                heatmap[x_val, y_val] = 200
            elseif model.pheremone_trails[x_val, y_val] > model.pheremone_floor
                heatmap[x_val, y_val] = model.pheremone_trails[x_val, y_val] ≥ model.pheremone_floor ? clamp(model.pheremone_trails[x_val, y_val], model.pheremone_floor, model.pheremone_ceiling) : 0
            else
                heatmap[x_val, y_val] = NaN
            end
        end
    end
    return heatmap
end

ant_color(ant::Ant) = ant.has_food ? :red : :black

plotkwargs = (
    ac = ant_color, as = 20, am = '♦',
    heatarray = antworld_heatmap, unikwargs...,
    heatkwargs = (colormap = Reverse(:viridis), colorrange = (0, 200),)
)
antworld = initialize_antworld(;number_ants = 125, random_seed = 6666, pheremone_amount = 60, evaporation_rate = 5)

antworld_obs = abmplot!(axs[6], antworld;
    plotkwargs..., unikwargs...,
    agent_step! = ant_step!, model_step! = antworld_step!,
)

models[6] = antworld_obs

# Fractal growth
@agent struct FractalParticle(ContinuousAgent{2,Float64})
    radius::Float64
    is_stuck::Bool
    spin_axis::Array{Float64,1}
end
PropFractalParticle(
    radius::Float64,
    spin_clockwise::Bool;
    is_stuck = false,
) = (SVector(0.0, 0.0), radius, is_stuck, [0.0, 0.0, spin_clockwise ? -1.0 : 1.0])

rand_circle(rng) = (θ = rand(rng, 0.0:0.1:359.9); (cos(θ), sin(θ)))
function particle_radius(min_radius::Float64, max_radius::Float64, rng)
    min_radius <= max_radius ? rand(rng, min_radius:0.01:max_radius) : min_radius
end

function initialize_fractal(;
    initial_particles::Int = 100, # initial particles in the model, not including the seed
    ## size of the space in which particles exist
    space_extents::NTuple{2,Float64} = (150.0, 150.0),
    speed = 0.5, # speed of particle movement
    vibration = 0.55, # amplitude of particle vibration
    attraction = 0.45, # velocity of particles towards the center
    spin = 0.55, # tangential velocity with which particles orbit the center
    ## fraction of particles orbiting clockwise. The rest are anticlockwise
    clockwise_fraction = 0.0,
    min_radius = 1.0, # minimum radius of any particle
    max_radius = 2.0, # maximum radius of any particle
    seed = 42,
)
    properties = Dict(
        :speed => speed,
        :vibration => vibration,
        :attraction => attraction,
        :spin => spin,
        :clockwise_fraction => clockwise_fraction,
        :min_radius => min_radius,
        :max_radius => max_radius,
        :spawn_count => 0,
    )
    ## space is periodic to allow particles going off one edge to wrap around to the opposite
    space = ContinuousSpace(space_extents; spacing = 1.0, periodic = true)
    model = StandardABM(FractalParticle, space; properties, rng = Random.MersenneTwister(seed))
    center = space_extents ./ 2.0
    for i in 1:initial_particles
        p_r = particle_radius(min_radius, max_radius, abmrng(model))
        prop_particle = PropFractalParticle(p_r, rand(abmrng(model)) < clockwise_fraction)
        ## `add_agent!` automatically gives the particle a random position in the space
        add_agent!(FractalParticle, model, prop_particle...)
    end
    ## create the seed particle
    p_r = particle_radius(min_radius, max_radius, abmrng(model))
    prop_particle = PropFractalParticle(p_r, true; is_stuck = true)
    ## here, we specified a position to give to the agent
    add_agent!(center, FractalParticle, model, prop_particle...)
    return model
end
function fractal_particle_step!(agent::FractalParticle, model)
    agent.is_stuck && returnS
    for id in nearby_ids(agent.pos, model, agent.radius)
        if model[id].is_stuck
            agent.is_stuck = true
            ## increment count to make sure another particle is spawned as this one gets stuck
            model.spawn_count += 1
            return
        end
    end
    ## radial vector towards the center of the space
    radial = abmspace(model).extent ./ 2.0 .- agent.pos
    radial = radial ./ norm(radial)
    ## tangential vector in the direction of orbit of the particle
    tangent = SVector{2}(cross([radial..., 0.0], agent.spin_axis)[1:2])
    agent.vel =
        (
            radial .* model.attraction .+ tangent .* model.spin .+
            rand_circle(abmrng(model)) .* model.vibration
        ) ./ (agent.radius^2.0)
    move_agent!(agent, model, model.speed)
end

# The `fractal_step!` function serves the sole purpose of spawning additional particles
# as they get stuck to the growing fractal.
function fractal_step!(model)
    while model.spawn_count > 0
        p_r = particle_radius(model.min_radius, model.max_radius, abmrng(model))
        pos = (rand_circle(abmrng(model)) .+ 1.0) .* abmspace(model).extent .* 0.49
        prop_particle = PropFractalParticle(p_r, rand(abmrng(model)) < model.clockwise_fraction))
        add_agent!(pos, FractalParticle, model, prop_particle...)
        model.spawn_count -= 1
    end
end

model = initialize_fractal()
fparticle_color(a::FractalParticle) = a.is_stuck ? :red : :blue
fparticle_size(a::FractalParticle) = 7.5 * a.radius

fractal_obs = abmplot!(axs[8], model;
    ac = fparticle_color,
    as = fparticle_size,
    am = '●',
    unikwargs...,
    agent_step! = fractal_particle_step!,
    model_step! = fractal_step!,
)

models[8] = fractal_obs

# Social distancing
@agent struct PoorSoul(ContinuousAgent{2,Float64})
    mass::Float64
    days_infected::Int  # number of days since is infected
    status::Symbol  # :S, :I or :R
    β::Float64
end
const steps_per_day = 24

function socialdistancing_init(;
    infection_period = 30 * steps_per_day,
    detection_time = 14 * steps_per_day,
    reinfection_probability = 0.05,
    isolated = 0.0, # in percentage
    interaction_radius = 0.012,
    dt = 1.0,
    speed = 0.002,
    death_rate = 0.044, # from website of WHO
    N = 1000,
    initial_infected = 5,
    seed = 42,
    βmin = 0.4,
    βmax = 0.8,
)

    properties = (;
        infection_period,
        reinfection_probability,
        detection_time,
        death_rate,
        interaction_radius,
        dt,
    )
    space = ContinuousSpace((1,1); spacing = 0.02)
    model = StandardABM(PoorSoul, space, properties = properties, rng = MersenneTwister(seed))

    ## Add initial individuals
    for ind in 1:N
        pos = Tuple(rand(abmrng(model), 2))
        status = ind ≤ N - initial_infected ? :S : :I
        isisolated = ind ≤ isolated * N
        mass = isisolated ? Inf : 1.0
        vel = isisolated ? (0.0, 0.0) : sincos(2π * rand(abmrng(model))) .* speed

        ## very high transmission probability
        ## we are modelling close encounters after all
        β = (βmax - βmin) * rand(abmrng(model)) + βmin
        add_agent!(pos, model, vel, mass, 0, status, β)
    end

    return model
end

function transmit!(a1, a2, rp)
    ## for transmission, only 1 can have the disease (otherwise nothing happens)
    count(a.status == :I for a in (a1, a2)) ≠ 1 && return
    infected, healthy = a1.status == :I ? (a1, a2) : (a2, a1)

    rand(abmrng(model)) > infected.β && return

    if healthy.status == :R
        rand(abmrng(model)) > rp && return
    end
    healthy.status = :I
end

function sir_agent_step!(agent, model)
    move_agent!(agent, model, model.dt)
    update!(agent)
    recover_or_die!(agent, model)
end
update!(agent) = agent.status == :I && (agent.days_infected += 1)
function recover_or_die!(agent, model)
    if agent.days_infected ≥ model.infection_period
        if rand(abmrng(model)) ≤ model.death_rate
            remove_agent!(agent, model)
        else
            agent.status = :R
            agent.days_infected = 0
        end
    end
end
function sir_model_step!(model)
    r = model.interaction_radius
    for (a1, a2) in interacting_pairs(model, r, :nearest)
        transmit!(a1, a2, model.reinfection_probability)
        elastic_collision!(a1, a2, :mass)
    end
end

sir_model = socialdistancing_init(isolated = 0.8)
sir_colors(a) = a.status == :S ? "#2b2b33" : a.status == :I ? "#bf2642" : "#338c54"

sir_obs = abmplot!(axs[9], sir_model;
ac = sir_colors,
as = 10, unikwargs...,
agent_step! = sir_agent_step!, model_step! = sir_model_step!,
)

models[9] = sir_obs

display(fig)

record(fig, "showcase.mp4", 1:100; framerate = 10) do i
    for j in 1:9
        obs = models[j]
        Agents.step!(obs, steps_per_frame[j])
    end
end

display(fig)

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
    "Bouncing particles",
]
steps_per_frame = [
    1,
    50,
    50,
    50,
    5,
    1,
    2,
    50,
    50,
]
models = ABMObservable[]
rules = []

fig = Figure(resolution = (1200, 1200))
axs = Axis[]
for (i, c) in enumerate(CartesianIndices((3,3)))
    ax = Axis(fig[c.I...]; title = model_names[i])
    hidedecorations!(ax)
    push!(axs, ax)
end


# %% DaisyWorld
daisypath = joinpath(pathof(Agents), "../../", "ext", "src", "daisyworld_def.jl")
include(daisypath)
daisy_model, daisy_step!, daisyworld_step! = daisyworld(;
    solar_luminosity = 1.0, solar_change = 0.0, scenario = :change
)
daisycolor(a::Daisy) = a.breed # agent color
as = 20    # agent size
am = '✿'  # agent marker
scatterkwargs = (strokewidth = 1.0,) # add stroke around each agent
heatarray = :temperature
heatkwargs = (colorrange = (-20, 60), colormap = :thermal)
plotkwargs = (;
    ac = daisycolor, as, am,
    scatterkwargs = (strokewidth = 1.0,),
    heatarray, heatkwargs, add_colorbar = false,
)

daisy_obs = abmplot!(axs[1], daisy_model; plotkwargs...)
push!(models, daisy_obs)
push!(rules, (daisy_step!, daisyworld_step!))

# %% Flocking
@agent Bird ContinuousAgent{2} begin
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

    model = ABM(Bird, space2d; rng, scheduler = Schedulers.Randomly())
    for _ in 1:n_birds
        vel = Tuple(rand(model.rng, 2) * 2 .- 1)
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
flock_obs = abmplot!(axs[2], flock_model; am = bird_marker)
push!(models, flock_obs)
push!(rules, (bird_step!, dummystep))

# %% Zombie outbreak
cd(@__DIR__)
using Agents, Random, FreeTypeAbstraction
using StatsBase: sample
using DrWatson: @dict
using GLMakie

"#765db4" # JuliaDynamics color
# %% Input
sir_colors(a) = a.status == :S ? "#2b2b33" : a.status == :I ? "#bf2642" : "#338c54"
NAGENTS = 800 # how many agents to create inside the text
fontname = "Moon2.0-Regular.otf"
SEED = 44
PERIOD = 18
BETA = 0.99
REINFECT = 0.00
DEATH = 0.2
INITINFECT = 30
SPEED = 0.002

# %% Run the script
logo_dims = (900, 300)
x, y = logo_dims
font = findfont("helvetica" )
m = transpose(zeros(UInt8, logo_dims...))

renderstring!(
    m,
    "Agents.jl",
    font,
    150,
    round(Int, y / 2) + 50,
    round(Int, x / 2),
    halign = :hcenter,

)

# heatmap(m; yflip=true, aspect_ratio=1)

const steps_per_day = 24

mutable struct PoorSoul <: AbstractAgent
    id::Int
    pos::NTuple{2,Float64}
    vel::NTuple{2,Float64}
    mass::Float64
    days_infected::Int  # number of days since is infected
    status::Symbol  # :S, :I or :R
    β::Float64
end

function transmit!(a1, a2, rp)
    ## for transmission, only 1 can have the disease (otherwise nothing happens)
    count(a.status == :I for a in (a1, a2)) ≠ 1 && return
    infected, healthy = a1.status == :I ? (a1, a2) : (a2, a1)

    rand() > infected.β && return

    if healthy.status == :R
        rand() > rp && return
    end
    healthy.status = :I
end

function sir_model_step!(model)
    r = model.interaction_radius
    for (a1, a2) in interacting_pairs(model, r, :all)
        transmit!(a1, a2, model.reinfection_probability)
        elastic_collision!(a1, a2, :mass)
    end
end

function sir_agent_step!(agent, model)
    move_agent!(agent, model, model.dt)
    update!(agent)
    recover_or_die!(agent, model)
end

update!(agent) = agent.status == :I && (agent.days_infected += 1)

function recover_or_die!(agent, model)
    if agent.days_infected ≥ model.infection_period
        if rand() ≤ model.death_rate
            kill_agent!(agent, model)
        else
            agent.status = :R
            agent.days_infected = 0
        end
    end
end

# Sample agents inside text
points = sample(findall(p -> p > 0.0, m), NAGENTS)
# Convert those into points that make sense within our continuous space (image coords must be y-inverted)
positions = map(
    p -> (last(p.I) / first(logo_dims), (last(logo_dims) - first(p.I)) / last(logo_dims)),
    points,
)

function sir_initiation(;
    infection_period = PERIOD * steps_per_day,
    reinfection_probability = REINFECT,
    isolated = 0.0, # in percentage
    interaction_radius = 0.011,
    dt = 1.0,
    speed = SPEED,
    death_rate = 0.044, # from website of WHO
    N = 1000,
    initial_infected = INITINFECT,
    seed = SEED,
    βmin = BETA,
    βmax = 1.0,
    init_static = [], #Array for logo
)

    properties = @dict(
        infection_period,
        reinfection_probability,
        death_rate,
        interaction_radius,
        dt,
    )
    space = ContinuousSpace((900.0, 300.0))
    model = ABM(PoorSoul, space, properties = properties)

    ## Add pre-defined static individuals
    #--------------------------------------
    for ind in 1:length(init_static)
        pos = init_static[ind]
        status = :S
        mass = Inf
        vel = (0.0, 0.0)
        β = (βmax - βmin) * rand() + βmin
        add_agent!(pos, model, vel, mass, 0, status, β)
    end
    #--------------------------------------
    ## Add initial individuals
    Random.seed!(seed)
    for ind in 1:N
        pos = Tuple(rand(2))
        status = ind ≤ N - initial_infected ? :S : :I
        isisolated = ind ≤ isolated * N
        mass = isisolated ? Inf : 1.0
        vel = isisolated ? (0.0, 0.0) : sincos(2π * rand()) .* speed

        ## very high transmission probability
        ## we are modelling close encounters after all
        β = (βmax - βmin) * rand() + βmin
        add_agent!(pos, model, vel, mass, 0, status, β)
    end
    return model
end

sir = sir_initiation(; N = 200, init_static = positions)

function init_plot(
    model::ABM{<:Union{GridSpace,ContinuousSpace}};
    ac = sir_colors,
    as = 10,
    am = :circle,
)
    ids = model.scheduler(model)
    colors = Observable(typeof(ac) <: Function ? [ac(model[i]) for i in ids] : ac)
    sizes = typeof(as) <: Function ? [as(model[i]) for i in ids] : as
    markers = typeof(am) <: Function ? [am(model[i]) for i in ids] : am
    pos = Observable([model[i].pos for i in ids])

    fig, ax, plot = scatter(
        pos;
        color = colors,
        markersize = sizes,
        marker = markers,
        figure = (resolution = logo_dims, )
        );
    return fig, colors, pos
end

function animstep!(pos, colors; ac = sir_colors)
    step!(sir, sir_agent_step!, sir_model_step!)
    ids = sir.scheduler(sir)
    pos[] = [sir[i].pos for i in ids]
    colors[] = typeof(ac) <: Function ? [ac(sir[i]) for i in ids] : ac
end

fig, colors, pos = init_plot(sir);

record(fig, "agents.gif", 1:1300; framerate=60) do i
    animstep!(pos, colors)
end
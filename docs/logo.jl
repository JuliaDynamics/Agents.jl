cd(@__DIR__)

using Agents, Random, Plots, AgentsPlots
using DrWatson: @dict
using StatsBase: sample
# using FreeTypeAbstraction
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
logo_dims = (900,300)
x, y = logo_dims
font = FTFont(joinpath(@__DIR__, fontname))
m = transpose(zeros(UInt8, logo_dims...))

renderstring!(
    m, "Agents.jl", font, 150, round(Int, y/2) + 50, round(Int, x/2),
    halign = :hcenter

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
    for (a1, a2) in interacting_pairs(model, r)
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
positions = map(p->(last(p.I)/first(logo_dims), (last(logo_dims)-first(p.I))/last(logo_dims)),points)

function sir_initiation(;
    infection_period = PERIOD * steps_per_day,
    reinfection_probability = REINFECT,
    isolated = 0.0, # in percentage
    interaction_radius = 0.011,
    dt = 1.0,
    speed = SPEED,
    death_rate = 0.044, # from website of WHO
    N = 1000, #Probably need to override
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
    space = ContinuousSpace(2)
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

    Agents.index!(model)
    return model
end

sir = sir_initiation(;N=200, init_static=positions)

anim = @animate for i in 1:1300
    p1 = plotabm(sir; ac = sir_colors, as = 3)
    plot!(p1; size = logo_dims)
    step!(sir, sir_agent_step!, sir_model_step!, 1)
end
gif(anim, "agents.gif", fps = 45)

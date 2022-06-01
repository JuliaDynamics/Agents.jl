const SEED = 44
const PERIOD = 18
# very high transmission probability
# we are modelling close encounters after all
const BETA = 0.99
const REINFECT = 0.00
const DEATH = 0.2
const INITINFECT = 0.5
const SPEED = 0.002
const AGENTS_IN_TEXT = 800 # how many agents to create inside the text
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

function transmit!(a1, a2, rp, rng)
    ## for transmission, only 1 can have the disease (otherwise nothing happens)
    count(a.status == :I for a in (a1, a2)) ≠ 1 && return
    infected, healthy = a1.status == :I ? (a1, a2) : (a2, a1)

    rand(rng) > infected.β && return

    if healthy.status == :R
        rand(rng) > rp && return
    end
    healthy.status = :I
end

function sir_model_step!(model)
    r = model.interaction_radius
    for (a1, a2) in interacting_pairs(model, r, :all)
        transmit!(a1, a2, model.reinfection_probability, model.rng)
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
        if rand(model.rng) ≤ model.death_rate
            kill_agent!(agent, model)
        else
            agent.status = :R
            agent.days_infected = 0
        end
    end
end

function sir_logo_initiation(;
        infection_period = PERIOD * steps_per_day,
        reinfection_probability = REINFECT,
        isolated = 0.0, # in percentage
        interaction_radius = 0.011,
        dt = 1.0,
        speed = SPEED,
        death_rate = 0.044, # from website of WHO
        N = 1000, # Agents outside text
        initial_infected = INITINFECT,
        seed = SEED,
        β = BETA,
    )

    # Sample agents inside text
    points = sample(findall(p -> p > 0.0, font_matrix), AGENTS_IN_TEXT)
    # Convert those into points that make sense within our continuous space (image coords must be y-inverted)
    init_static = map(
        p -> (p.I[2]/100, (logo_dims[2] - p.I[1])/100),
        points,
    )

    properties = (;
        infection_period,
        reinfection_probability,
        death_rate,
        interaction_radius,
        dt,
    )
    rng = Random.Xoshiro(seed)
    space = ContinuousSpace(logo_dims ./ 100)
    model = ABM(PoorSoul, space; rng, properties)

    ## Add pre-defined static individuals
    #--------------------------------------
    for ind in 1:length(init_static)
        pos = init_static[ind]
        status = :S
        mass = Inf
        vel = (0.0, 0.0)
        add_agent!(pos, model, vel, mass, 0, status, β)
    end
    #--------------------------------------
    ## Add initial individuals
    for ind in 1:N
        status = ind ≤ N - initial_infected*N ? :S : :I
        isisolated = ind ≤ isolated * N
        mass = isisolated ? Inf : 1.0
        vel = isisolated ? (0.0, 0.0) : sincos(2π * rand(rng)) .* speed

        add_agent!(model, vel, mass, 0, status, β)
    end
    return model
end

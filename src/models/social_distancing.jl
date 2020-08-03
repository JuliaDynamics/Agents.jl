using Random

mutable struct PoorSoul <: AbstractAgent
    id::Int
    pos::NTuple{2,Float64}
    vel::NTuple{2,Float64}
    mass::Float64
    days_infected::Int  # number of days since is infected
    status::Symbol  # :S, :I or :R
    β::Float64
end


const steps_per_day = 24

"""
```julia
social_distancing(;
    infection_period = 30 * steps_per_day,
    detection_time = 14 * steps_per_day,
    reinfection_probability = 0.05,
    isolated = 0.5, # in percentage
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
```
Same as in [Continuous space social distancing for COVID-19](@ref).
"""
function social_distancing(;
        infection_period = 30 * steps_per_day,
        detection_time = 14 * steps_per_day,
        reinfection_probability = 0.05,
        isolated = 0.5, # in percentage
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

    properties = Dict(
        :infection_period => infection_period,
        :reinfection_probability => reinfection_probability,
        :detection_time => detection_time,
        :death_rate => death_rate,
        :interaction_radius => interaction_radius,
        :dt => dt,
    )
    space = ContinuousSpace(2)
    model = ABM(PoorSoul, space, properties = properties)

    Random.seed!(seed)
    for ind in 1:N
        pos = Tuple(rand(2))
        status = ind ≤ N - initial_infected ? :S : :I
        isisolated = ind ≤ isolated * N
        mass = isisolated ? Inf : 1.0
        vel = isisolated ? (0.0, 0.0) : sincos(2π * rand()) .* speed
        β = (βmax - βmin) * rand() + βmin
        add_agent!(pos, model, vel, mass, 0, status, β)
    end

    Agents.index!(model)
    return model, social_distancing_agent_step!, social_distancing_model_step!
end


function sd_transmit!(a1, a2, rp)
    count(a.status == :I for a in (a1, a2)) ≠ 1 && return
    infected, healthy = a1.status == :I ? (a1, a2) : (a2, a1)

    rand() > infected.β && return

    if healthy.status == :R
        rand() > rp && return
    end
    healthy.status = :I
end

function social_distancing_model_step!(model)
    r = model.interaction_radius
    for (a1, a2) in interacting_pairs(model, r, :nearest)
        sd_transmit!(a1, a2, model.reinfection_probability)
        elastic_collision!(a1, a2, :mass)
    end
end


function social_distancing_agent_step!(agent, model)
    move_agent!(agent, model, model.dt)
    sd_update!(agent)
    recover_or_die!(agent, model)
end

sd_update!(agent) = agent.status == :I && (agent.days_infected += 1)

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

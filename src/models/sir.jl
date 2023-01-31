using LinearAlgebra
using Agents.Graphs

@agent PoorSoul GraphAgent begin
    days_infected::Int  # number of days since is infected
    status::Symbol  # 1: S, 2: I, 3:R
end

"""
```julia
sir(;
    C = 8,
    max_travel_rate = 0.01,
    Ns = rand(50:5000, C),
    β_und = rand(0.3:0.02:0.6, C),
    β_det = β_und ./ 10,
    infection_period = 30,
    reinfection_probability = 0.05,
    detection_time = 14,
    death_rate = 0.02,
    Is = [zeros(Int, length(Ns) - 1)..., 1],
    seed = 19,
)
```
Same as in [SIR model for the spread of COVID-19](@ref).
"""
function sir(;
    C = 8,
    max_travel_rate = 0.01,
    Ns = rand(50:5000, C),
    β_und = rand(0.3:0.02:0.6, C),
    β_det = β_und ./ 10,
    infection_period = 30,
    reinfection_probability = 0.05,
    detection_time = 14,
    death_rate = 0.02,
    Is = [zeros(Int, length(Ns) - 1)..., 1],
    seed = 19,
)

    rng = MersenneTwister(seed)
    migration_rates = zeros(C, C)
    @assert length(Ns) ==
    length(Is) ==
    length(β_und) ==
    length(β_det) ==
    size(migration_rates, 1) "length of Ns, Is, and B, and number of rows/columns in migration_rates should be the same "
    @assert size(migration_rates, 1) == size(migration_rates, 2) "migration_rates rates should be a square matrix"

    for c in 1:C
        for c2 in 1:C
            migration_rates[c, c2] = (Ns[c] + Ns[c2]) / Ns[c]
        end
    end
    maxM = maximum(migration_rates)
    migration_rates = (migration_rates .* max_travel_rate) ./ maxM
    migration_rates[diagind(migration_rates)] .= 1.0

    ## normalize migration_rates
    migration_rates_sum = sum(migration_rates, dims = 2)
    for c in 1:C
        migration_rates[c, :] ./= migration_rates_sum[c]
    end

    properties = Dict(
        :Ns => Ns,
        :Is => Is,
        :β_und => β_und,
        :β_det => β_det,
        :migration_rates => migration_rates,
        :infection_period => infection_period,
        :infection_period => infection_period,
        :reinfection_probability => reinfection_probability,
        :detection_time => detection_time,
        :C => C,
        :death_rate => death_rate
    )

    space = GraphSpace(complete_digraph(C))
    model = ABM(PoorSoul, space; properties, rng)

    ## Add initial individuals
    for city in 1:C, n in 1:Ns[city]
        ind = add_agent!(city, model, 0, :S) # Susceptible
    end
    ## add infected individuals
    for city in 1:C
        inds = ids_in_position(city, model)
        for n in 1:Is[city]
            agent = model[inds[n]]
            agent.status = :I # Infected
            agent.days_infected = 1
        end
    end
    return model, sir_agent_step!, dummystep
end

function sir_agent_step!(agent, model)
    sir_migrate!(agent, model)
    sir_transmit!(agent, model)
    sir_update!(agent, model)
    sir_recover_or_die!(agent, model)
end

function sir_migrate!(agent, model)
    pid = agent.pos
    d = DiscreteNonParametric(1:(model.C), model.migration_rates[pid, :])
    m = rand(model.rng, d)
    if m ≠ pid
        move_agent!(agent, m, model)
    end
end

function sir_transmit!(agent, model)
    agent.status == :S && return
    rate = if agent.days_infected < model.detection_time
        model.β_und[agent.pos]
    else
        model.β_det[agent.pos]
    end

    d = Poisson(rate)
    n = rand(model.rng, d)
    n == 0 && return

    for contactID in ids_in_position(agent, model)
        contact = model[contactID]
        if contact.status == :S ||
           (contact.status == :R && rand(model.rng) ≤ model.reinfection_probability)
            contact.status = :I
            n -= 1
            n == 0 && return
        end
    end
end

sir_update!(agent, model) = agent.status == :I && (agent.days_infected += 1)

function sir_recover_or_die!(agent, model)
    if agent.days_infected ≥ model.infection_period
        if rand(model.rng) ≤ model.death_rate
            kill_agent!(agent, model)
        else
            agent.status = :R
            agent.days_infected = 0
        end
    end
end
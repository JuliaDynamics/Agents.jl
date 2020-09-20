using Agents, Random, DataFrames, LightGraphs
using Distributions: Poisson, DiscreteNonParametric
using DrWatson: @dict
using LinearAlgebra: diagind

mutable struct PoorSoul <: AbstractAgent
    id::Int
    pos::Int
    days_infected::Int  # number of days since is infected
    status::Symbol  # 1: S, 2: I, 3:R
end

function model_initiation(;
    Ns = [500, 500, 500],
    migration_rate = 0.2,
    death_rate = 0.1,
    β_det = 0.05,
    β_und = 0.1,
    infection_period = 10,
    reinfection_probability = 0.05,
    detection_time = 3,
    Is = ones(Int, length(Ns)),
    seed = nothing,
)

    if !isnothing(seed)
        Random.seed!(seed)
    end

    C = length(Ns)
    β_det = [β_det for i in 1:C]
    β_und = [β_und for i in 1:C]

    migration_rates = reshape([migration_rate for i in 1:(C * C)], C, C)
    # normalize migration_rates
    migration_rates_sum = sum(migration_rates, dims = 2)
    for c in 1:C
        migration_rates[c, :] ./= migration_rates_sum[c]
    end

    properties = @dict(
        Ns,
        β_und,
        β_det,
        migration_rates,
        infection_period,
        reinfection_probability,
        detection_time,
        death_rate,
        Is,
        C,
    )
    space = GraphSpace(complete_digraph(C))
    model = ABM(PoorSoul, space; properties = properties)

    # Add initial individuals
    for city in 1:C, n in 1:Ns[city]
        add_agent!(city, model, 0, :S) # Susceptible
    end
    # add infected individuals
    for city in 1:C
        inds = agents_in_pos(city, model)
        for n in 1:Is[city]
            agent = model[inds[n]]
            agent.status = :I # Infected
            agent.days_infected = 1
        end
    end
    return model
end

function agent_step!(agent, model)
    migrate!(agent, model)
    transmit!(agent, model)
    update_status!(agent, model)
    recover_or_die!(agent, model)
end

function migrate!(agent, model)
    pid = agent.pos
    d = DiscreteNonParametric(1:(model.C), model.migration_rates[pid, :])
    m = rand(d)
    if m ≠ pid
        move_agent!(agent, m, model)
    end
end

function transmit!(agent, model)
    agent.status == :S && return
    rate = if agent.days_infected < model.detection_time
        model.β_und[agent.pos]
    else
        model.β_det[agent.pos]
    end

    d = Poisson(rate)
    n = rand(d)
    n == 0 && return

    for contactID in agents_in_pos(agent, model)
        contact = model[contactID]
        if contact.status == :S ||
           (contact.status == :R && rand() ≤ model.reinfection_probability)
            contact.status = :I
            n -= 1
            n == 0 && return
        end
    end
end

update_status!(agent, model) = agent.status == :I && (agent.days_infected += 1)

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



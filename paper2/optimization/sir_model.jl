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
    Ns,
    migration_rates,
    β_und,
    β_det,
    infection_period = 10,
    reinfection_probability = 0.05,
    detection_time = 3,
    death_rate = 0.02,
    Is = ones(Int, length(Ns)),
    seed = nothing,
  )

    if !isnothing(seed)
        Random.seed!(seed)
    end
    @assert length(Ns) ==
    length(Is) ==
    length(β_und) ==
    length(β_det) ==
    size(migration_rates, 1) "length of Ns, Is, and B, and number of rows/columns in migration_rates should be the same "
    @assert size(migration_rates, 1) == size(migration_rates, 2) "migration_rates rates should be a square matrix"

    C = length(Ns)
    # normalize migration_rates
    migration_rates_sum = sum(migration_rates, dims = 2)
    for c in 1:C
        migration_rates[c, :] ./= migration_rates_sum[c]
    end

    properties = @dict(
        Ns,
        Is,
        β_und,
        β_det,
        β_det,
        migration_rates,
        infection_period,
        infection_period,
        reinfection_probability,
        detection_time,
        C,
        death_rate
    )
    space = GraphSpace(complete_digraph(C))
    model = ABM(PoorSoul, space; properties = properties)

    # Add initial individuals
    for city in 1:C, n in 1:Ns[city]
        ind = add_agent!(city, model, 0, :S) # Susceptible
    end
    # add infected individuals
    for city in 1:C
        inds = get_node_contents(city, model)
        for n in 1:Is[city]
            agent = model[inds[n]]
            agent.status = :I # Infected
            agent.days_infected = 1
        end
    end
    return model
end

function create_params(;
  C,
  Ns,
  β_det,
  migration_rate,
  infection_period = 10,
  reinfection_probability = 0.05,
  detection_time = 3,
  death_rate = 0.02,
  Is = ones(Int, C),
  β_und = [0.1 for i in 1:C],
  )

  migration_rates = reshape([migration_rate for i in 1:C*C], C,C)

  params = @dict(
      Ns,
      β_und,
      β_det,
      migration_rates,
      infection_period,
      reinfection_probability,
      detection_time,
      death_rate,
      Is
  )

  return params
end

function agent_step!(agent, model)
  migrate!(agent, model)
  transmit!(agent, model)
  update!(agent, model)
  recover_or_die!(agent, model)
end

function migrate!(agent, model)
  nodeid = agent.pos
  d = DiscreteNonParametric(1:(model.C), model.migration_rates[nodeid, :])
  m = rand(d)
  if m ≠ nodeid
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

#   if rate < 0.0 
#     rate = 0.0
#   end
  d = Poisson(rate)
  n = rand(d)
  n == 0 && return

  for contactID in get_node_contents(agent, model)
      contact = model[contactID]
      if contact.status == :S ||
         (contact.status == :R && rand() ≤ model.reinfection_probability)
          contact.status = :I
          n -= 1
          n == 0 && return
      end
  end
end

update!(agent, model) = agent.status == :I && (agent.days_infected += 1)

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

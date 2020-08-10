# # Optimizing agent-based models

# Agent-based models (ABMs) are often computationally expensive and can have many parameters. Sometimes we need to fine-tune a model's parameters to a specific outcome. Brute-force algorithms can take too long for testing each parameter setting. Even if it was feasbile to run the model for every parameter setting, it would not be enough because ABMs are stochastic and the effect of a parameter setting should be derived from running the model several times and taking its average behavior.

# Here we show how to use the evolutionary algorithms in [BlackBoxOptim.jl](https://github.com/robertfeldt/BlackBoxOptim.jl) with Agents.j

# We optimize the parameters of our SIR model. First we define the ABM:

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

# Now we need to define a cost function. The cost function takes as agruments the model parameters that we want to tune, here migration rate, death rate, transmission rate when an infected person has been (not) detected (`β_det`, `β_und`), infection period, reinfection probability, and time until the infection is detected. The function returns one or more numbers as the objective to be minimized. Here, we try to minimize the number of infected people after 50 days.

using BlackBoxOptim
import Statistics: mean

function cost(x)
  migration_rate, death_rate, β_det, β_und, infection_period, reinfection_probability, detection_time = x
  C = 3
  params = create_params(C=C,
  Ns=[500 for i in 1:C],
  β_det=[β_det for i in 1:C],
  migration_rate=migration_rate,
  infection_period = infection_period,
  reinfection_probability = reinfection_probability,
  detection_time = detection_time,
  death_rate = death_rate,
  Is = ones(Int, C),
  β_und = [β_und for i in 1:C]
  )

  model = model_initiation(; params...)

  infected_fraction(model) = count(a.status == :I for a in values(model.agents)) / nagents(model)
  _, data = run!(model, agent_step!, 50; mdata = [infected_fraction], when_model=[50], replicates=10)

  return mean(data.infected_fraction)
end

# Because ABMs are stochastic, we run 10 replicates and take the average fraction of infected people after 50 days 

# We can now test the function cost with some reasonable parameter values.

Random.seed!(10)

migration_rate=0.2
death_rate=0.1
β_det = 0.05
β_und = 0.3
infection_period = 10
reinfection_probability = 0.1
detection_time = 5
x0 = [migration_rate, death_rate, β_det, β_und, infection_period, reinfection_probability, detection_time]
cost(x0)

# After 50 days, 94% of the population is infected.

# We let the optimization algorithm change parameters to minimize the number of infected individuals. Note that we can limit the allowed range for each parameter separately.

result = bboptimize(cost, SearchRange = [(0.0, 1.0), (0.0, 1.0), (0.0, 1.0), (0.0, 1.0), (7.0, 13.0),(0.0, 1.0),(2.0, 6.0)], NumDimensions = 7, MaxTime=20)
best_fitness(result)

# The fraction of the infected is down to 11%. Parameter values that give this result are:

best_candidate(result)

# We notice that the death rate is 96%, and transmission rates have also increased, while reinfection probability is much smaller. When all the infected indiduals die, infection doesn't transmit. Let's modify the cost function to also keep the mortality rate low.

# This can be tested by running the model with the new parameter values:
migration_rate, death_rate, β_det, β_und, infection_period, reinfection_probability, detection_time = best_candidate(result)
C = 3
params = create_params(C=C,
Ns=[500 for i in 1:C],
β_det=[β_det for i in 1:C],
migration_rate=migration_rate,
infection_period = infection_period,
reinfection_probability = reinfection_probability,
detection_time = detection_time,
death_rate = death_rate,
Is = ones(Int, C),
β_und = [β_und for i in 1:C]
)

Random.seed!(0)
model = model_initiation(; params...)
nagents(model)

_ , data = run!(model, agent_step!, 50; mdata = [nagents], when_model=[50], replicates = 10)

mean(data.nagents)

# About 10% of the population dies with these parameters.

# We can define a multi-objective cost function that minimizes the number of infected and deaths.

function cost_multi(x)
  migration_rate, death_rate, β_det, β_und, infection_period, reinfection_probability, detection_time = x
  C = 3
  params = create_params(C=C,
    Ns=[500 for i in 1:C],
    β_det=[β_det for i in 1:C],
    migration_rate=migration_rate,
    infection_period = infection_period,
    reinfection_probability = reinfection_probability,
    detection_time = detection_time,
    death_rate = death_rate,
    Is = ones(Int, C),
    β_und = [β_und for i in 1:C]
  )

  model = model_initiation(; params...)
  initial_size = nagents(model)

  infected_fraction(model) = count(a.status == :I for a in values(model.agents)) / nagents(model)
  n_fraction(model) = -1.0 * nagents(model)/initial_size
  _, data = run!(model, agent_step!, 50; mdata = [infected_fraction, n_fraction], when_model=[50], replicates=10)

  return mean(data.infected_fraction), mean(data.n_fraction)
end

# The cost of our initial parameter values is high: most of the population (96%) is infected and 22% die.

cost_multi(x0)

# Let's minimize this multi-objective cost function. We need to define the optimization method for multi-objective functions:

result = bboptimize(cost_multi, Method=:borg_moea, FitnessScheme=ParetoFitnessScheme{2}(is_minimizing=true), SearchRange = [(0.0, 1.0), (0.0, 1.0), (0.0, 1.0), (0.0, 1.0), (7.0, 13.0),(0.0, 1.0),(2.0, 6.0)], NumDimensions = 7, MaxTime=55)

# With the optimized parameters, about 0.3% of the population dies and 0.02% are infected:

best_fitness(result)

# And the tuned parameters are

best_candidate(result)

# The algorithm managed to minimize the the number of infected and deaths while still increasing death rate to 42%, reinfection probability to 53%, and migration rates to 33%. The most important change decreasing the transmission rate when individuals are infected and undetected (from 30% to 0.2%).

# Let's reduce death rate and check the cost:

x = best_candidate(result)
x[2] = 0.02
cost_multi(x)

# The fraction of infected increases to 0.04%. This is an interesting result, confirming the importance of social distancing. Without changing infection period and travel rate, even by increasing the transmission rate of the infected and detected (from 5% to 20%), by just decreasing the transmission rate of the undetected individuals, death rate drops 73 times and the number of infected decreases from 96% of the population to 3%.

using BlackBoxOptim
import Statistics: mean
include("sir_model.jl")

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

migration_rate=0.2
death_rate=0.1
β_det = 0.05
β_und = 0.3
infection_period = 10
reinfection_probability = 0.1
detection_time = 5
x0 = [migration_rate, death_rate, β_det, β_und, infection_period, reinfection_probability, detection_time]
cost(x0)

result = bboptimize(cost, SearchRange = [(0.0, 1.0), (0.0, 1.0), (0.0, 1.0), (0.0, 1.0), (7.0, 13.0),(0.0, 1.0),(2.0, 6.0)], NumDimensions = 7, MaxTime=15)

best_fitness(result)
best_candidate(result)

## Multi-objective optimization

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
  recovered_fraction(model) = -count(a.status == :R for a in values(model.agents)) / nagents(model)
  n_fraction(model) = -1.0 * nagents(model)/initial_size
  _, data = run!(model, agent_step!, 50; mdata = [infected_fraction, n_fraction], when_model=[50], replicates=10)

  return mean(data.infected_fraction[1]), mean(data.n_fraction[1])
end

migration_rate=0.2
death_rate=0.1
β_det = 0.05
β_und = 0.3
infection_period = 10
reinfection_probability = 0.1
detection_time = 5
x0 = [migration_rate, death_rate, β_det, β_und, infection_period, reinfection_probability, detection_time]
cost_multi(x0)

result = bboptimize(cost_multi, Method=:borg_moea, FitnessScheme=ParetoFitnessScheme{2}(is_minimizing=true), SearchRange = [(0.0, 1.0), (0.0, 1.0), (0.0, 1.0), (0.0, 1.0), (7.0, 13.0),(0.0, 1.0),(2.0, 6.0)], NumDimensions = 7, MaxTime=30)

best_fitness(result)
best_candidate(result)
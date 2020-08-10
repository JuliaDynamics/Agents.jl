using FiniteDifferences
import Statistics: mean
include("sir_model.jl")

function cost(migration_rate, death_rate, β_det, β_und, infection_period, reinfection_probability, detection_time)
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

function optimize(;iterations=5, α = 0.7)
  migration_rate=0.2
  death_rate=0.1
  β_det = 0.05
  β_und = 0.3
  infection_period = 10
  reinfection_probability = 0.1
  detection_time = 5

  initial_cost = cost(migration_rate, death_rate, β_det, β_und, infection_period, reinfection_probability, detection_time)

  for iter in 1:iterations
    # Take their gradients
    grads = grad(central_fdm(3, 1), cost, migration_rate, death_rate, β_det, β_und, infection_period, reinfection_probability, detection_time)
    # update params
    migration_rate -= α*grads[1]
    death_rate -= α*grads[2]
    β_det -= α*grads[3]
    β_und -= α*grads[4]
    infection_period -= α*grads[5]
    reinfection_probability -= α*grads[6]
    detection_time -= α*grads[7]
  end
  optimized_cost = cost(migration_rate, death_rate, β_det, β_und, infection_period, reinfection_probability, detection_time)

  return initial_cost, optimized_cost, migration_rate, death_rate, β_det, β_und, infection_period, reinfection_probability, detection_time
end

initial_cost, optimized_cost, migration_rate, death_rate, β_det, β_und, infection_period, reinfection_probability, detection_time = optimize(iterations=5, α=0.7)

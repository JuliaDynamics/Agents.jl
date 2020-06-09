using BlackBoxOptim
include("sir_model.jl")

function cost(x)
  max_travel_rate, death_rate, β_und1, β_und2, β_und3 = x
  params = create_params(C = 3, max_travel_rate = max_travel_rate, infection_period = 30, 
    reinfection_probability = 0.05,
    detection_time = 14,
    death_rate = death_rate,
    β_und = [β_und1, β_und2, β_und3],
    seed = 19
  )

  model = model_initiation(; params...)

  infected_fraction(model) = count(a.status == :I for a in values(model.agents)) / nagents(model)
  _, data = run!(model, agent_step!, 10; mdata = [infected_fraction], when_model=[10])

  return data.infected_fraction[1]
end


max_travel_rate = 0.1
death_rate=0.02
β_und1=0.1; β_und2=0.2; β_und3=0.3
x0 = [max_travel_rate, death_rate, β_und1, β_und2, β_und3]
cost(x0)

result = bboptimize(cost, SearchRange = (0.0, 1.0), NumDimensions = 5, MaxTime=15)

best_fitness(result)
best_candidate(result)

## Multi-objective optimization

function cost_multi(x)
  max_travel_rate, death_rate, β_und1, β_und2, β_und3 = x
  params = create_params(C = 3, max_travel_rate = max_travel_rate, infection_period = 30, 
    reinfection_probability = 0.05,
    detection_time = 14,
    death_rate = death_rate,
    β_und = [β_und1, β_und2, β_und3],
    seed = 19
  )

  model = model_initiation(; params...)

  infected_fraction(model) = count(a.status == :I for a in values(model.agents)) / nagents(model)
  recovered_fraction(model) = -count(a.status == :R for a in values(model.agents)) / nagents(model)
  _, data = run!(model, agent_step!, 10; mdata = [infected_fraction, population_size], when_model=[10])

  return data.infected_fraction[1], data.recovered_fraction[1]
end


result = bboptimize(cost_multi, Method=:borg_moea, FitnessScheme=ParetoFitnessScheme{2}(is_minimizing=true), SearchRange = (0.0, 1.0), NumDimensions = 5, MaxTime=30)

best_fitness(result)
best_candidate(result)
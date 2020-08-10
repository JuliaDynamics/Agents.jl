using FiniteDifferences
include("sir_model.jl")

function cost(max_travel_rate, reinfection_probability, detection_time, death_rate, β_und1, β_und2, β_und3)
  params = create_params(C = 3, max_travel_rate = max_travel_rate, infection_period = 30, 
    reinfection_probability = reinfection_probability,
    detection_time = detection_time,
    death_rate = death_rate,
    β_und = [β_und1, β_und2, β_und3],
    seed = 19
  )

  model = model_initiation(; params...)

  infected_fraction(model) = count(a.status == :I for a in values(model.agents)) / nagents(model)
  _, data = run!(model, agent_step!, 10; mdata = [infected_fraction], when_model=[10])

  return data.infected_fraction[1]
end


function optimize(;iterations=5, α = 0.7)
  max_travel_rate = 0.1
  reinfection_probability=0.05
  detection_time=14
  death_rate=0.02
  β_und1=0.1; β_und2=0.2; β_und3=0.3

  initial_cost = cost(max_travel_rate, reinfection_probability, detection_time, death_rate, β_und1, β_und2, β_und3)

  for iter in 1:iterations
    # Take their gradients
    grads = grad(central_fdm(3, 1), cost, max_travel_rate, reinfection_probability, detection_time, death_rate, β_und1, β_und2, β_und3)
    # update params
    max_travel_rate -= α*grads[1]
    reinfection_probability -= α*grads[2]
    detection_time -= α*grads[3]
    death_rate -= α*grads[4]
    β_und1 -= α*grads[5]
    β_und2 -= α*grads[6]
    β_und3 -= α*grads[7]
  end
  optimized_cost = cost(max_travel_rate, reinfection_probability, detection_time, death_rate, β_und1, β_und2, β_und3)

  return initial_cost, optimized_cost, max_travel_rate,  reinfection_probability, detection_time, death_rate, β_und1, β_und2, β_und3
end

initial_cost, optimized_cost, max_travel_rate, reinfection_probability, detection_time, death_rate, β_und1, β_und2, β_und3 = optimize(iterations=5, α=0.7)

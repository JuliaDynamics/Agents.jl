# # SIR model for spread of COVID-19

# ## SIR model

# SIR model tracks the ratio of Susceptible, Infected, and Recovered individuals within a population. Here we add one more category of individuals: those who are infected, but do not know it. Transmission rate of infected and diagnosed is lower than infected and undetected.
# We also allow a fraction of recovered individuals to catch the disease again. The disease does not bring full immunity.

# ### Model parameters

# * Ns: a list of population sizes per city.
# * migration_rates: A matrix of migration probability per individual per day from one city to another.
# * Is: An array for initial number of infected but undetected people per city.
# * Bu: an array for transmission probabilities β of the infected but undetected per city. Transmission probability is how many susceptiple are infected per day by and infected individual. If social distancing is practiced, this number increases.
# * Bd: an array for transmission probabilities β of the infected and detected per city. If hospitals are full, this number increases.
# * infection_period: how many days before a person dies or recovers.
# * reinfection_probability
# * time to detect in days: how long before an infected person is detected?

using Agents
using Random
using Distributions
using VegaLite
using DataFrames

mutable struct Ind <: AbstractAgent
  id::Int
	pos::Tuple{Int, Int}
	infected::Int  # number of days since is infected
  status::Int  # 1: S, 2: I, 3:R
end

function model_initiation(;Ns, migration_rates, Is, Bu, Bd, infection_period, reinfection_probability, time_to_detect, death_rate, seed=0)
	Random.seed!(seed)

	@assert length(Ns) == length(Is) == length(Bu) == length(Bd) == size(migration_rates, 1) "length of Ns, Is, and B, and number of rows/columns in migration_rates should be the same "
	@assert size(migration_rates, 1) == size(migration_rates, 2) "migration_rates rates should be a square matrix"

	ncities = length(Ns)
	# normalize migration_rates
	migration_rates_sum = sum(migration_rates, dims=2)
	for c in 1:ncities
		migration_rates[c, :] ./= migration_rates_sum[c]
	end

  space = Space((3, 1))
  properties = Dict(:Ns => Ns, :Is => Is, :Bu => Bu, :Bd => Bd, :migration_rates => migration_rates, :infection_period => infection_period, :reinfection_probability => reinfection_probability, :time_to_detect => time_to_detect, :ncities => ncities, :death_rate => death_rate)
  model = ABM(Ind, space; properties=properties)

  # Add initial individuals
  for city in 1:ncities
		for n in 1:Ns[city]
			ind = add_agent!(city, model, 0, 1)
		end
	end
	# add infected individuals
	for city in 1:ncities
		inds = get_node_contents(city, model)
		for n in 1:Is[city]
			model.agents[inds[n]].status = 2
			model.agents[inds[n]].infected = 1
		end
	end

  return model
end

function agent_step!(agent, model)
	migrate!(agent, model)
	transmit(agent, model)
	update!(agent, model)
	recover_or_die!(agent, model)
end

function migrate!(agent, model)
	nodeid = coord2vertex(agent, model)
	d = DiscreteNonParametric(1:model.properties[:ncities], model.properties[:migration_rates][nodeid, :])
	m = rand(d)
	if m != nodeid
		move_agent!(agent, m, model)
	end
end

function transmit(agent, model)
	if agent.status == 1
		return
	end
	rate = agent.infected < model.properties[:time_to_detect] ? model.properties[:Bu][coord2vertex(agent, model)] : model.properties[:Bd][coord2vertex(agent, model)]
	d = Poisson(rate)
	n = rand(d)
	if n == 0
		return
	end
	for contactID in get_node_contents(agent, model)
		contact = model.agents[contactID]
		if contact.status == 1 || (contact.status == 3 && rand() <= model.properties[:reinfection_probability])
			contact.status = 2
			n -= 1
			if n == 0
				return
			end
		end
	end
end

function update!(agent, model)
	if agent.status == 2
		agent.infected += 1
	end
end

function recover_or_die!(agent, model)
	if agent.infected == model.properties[:infection_period]
		if rand() <= model.properties[:death_rate]
			kill_agent!(agent, model)
		else
			agent.status = 3
			agent.infected = 0
		end
	end
end

# # Example

params = Dict(
	:Ns => [5000, 2000, 1000],
	# Let's start from a single infected individual in a smaller city.
	:Is => [0, 0, 1],
	:Bu => [0.6, 0.6, 0.6],
	:Bd => [0.07, 0.07, 0.07],
	# people from smaller cities are more likely to travel to bigger cities. Migration rates from from row i to column j.
	:migration_rates => [1 0.01 0.005;0.015 1 0.007; 0.02 0.018 1],
	:infection_period => 30,
	:time_to_detect => 14,
	:reinfection_probability => 0.05,
	:death_rate => 0.01
)

model = model_initiation(;params...)

infected(x) = length([i for i in x if i == 2])
recovered(x) = length([i for i in x if i == 3])

data_to_collect = Dict(:status => [infected, recovered, length])
data = step!(model, agent_step!, 300, data_to_collect)

# Reshape data before plotting
dnames = names(data)
steps = size(data, 1)
d = DataFrame(
	:counts => vcat(data[!, 1], data[!, 2], data[!, 3]),
	:group => vcat(repeat(["Infected"], steps), repeat(["N"], steps), repeat(["Recovered"], steps)),
	:step => repeat(data[!, :step], 3)
)

p = @vlplot(
	data = d,
	mark = :line,
	x = :step,
	y = :counts,
	color = :group
)
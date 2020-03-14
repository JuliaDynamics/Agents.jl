# # SIR model for spread of COVID-19

# ## SIR model

# SIR model tracks the ratio of Susceptible, Infected, and Recovered individuals within a population.
# Here we add one more category of individuals: those who are infected, but do not know it.
# Transmission rate of infected and diagnosed is lower than infected and undetected.
# We also allow a fraction of recovered individuals to catch the disease again, meaning
# that recovering the disease does not bring full immunity.

# ## Model parameters
# The following parameters should be specified by the user
# * Bu: an array for transmission probabilities β of the infected but undetected per city.
#   Transmission probability is how many susceptiple are infected per day by and infected individual.
#   If social distancing is practiced, this number increases.
# * Bd: an array for transmission probabilities β of the infected and detected per city.
#   If hospitals are full, this number increases.
# * infection_period: how many days before a person dies or recovers.
# * time to detect in days: how long before an infected person is detected?
# * reinfection_probability: The probabiity that a recovered person can get infected again.

# And the following optional parameters are created during model creation
# * `C=8`: the number of cities.
# * `Ns=1000*edges_number`: a list of population sizes per city.
# * `Is = 0.01 .* Ns`: An array for initial number of infected but undetected people per city.
# * `migration_rates`: A matrix of migration probability per individual per day from one city to another.

# ## Making the model in Agents.jl
# We start by defining the Agent type and the ABM

#TODO: Increase readability of "status" by making it a symbol field

using Agents, Random, Distributions, DataFrames

mutable struct Agent <: AbstractAgent
    id::Int
    pos::Int
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

		space = Space(complete_digraph(ncities))
		
		properties = Dict(:Ns => Ns, :Is => Is, :Bu => Bu, :Bd => Bd, :migration_rates => migration_rates, :infection_period => infection_period, :reinfection_probability => reinfection_probability, :time_to_detect => time_to_detect, :ncities => ncities, :death_rate => death_rate)
    model = ABM(Agent, space; properties=properties)

    # Add initial individuals
    for city in 1:ncities, n in 1:Ns[city]
        ind = add_agent!(city, model, 0, 1)
    end
    # add infected individuals
    for city in 1:ncities
        inds = get_node_contents(city, model)
        for n in 1:Is[city]
            agent = id2agent(inds[n], model)
            agent.status = 2
            agent.infected = 1
        end
    end

    return model
end

# Now we define the functions for stepping

function agent_step!(agent, model)
    migrate!(agent, model)
    transmit!(agent, model)
    update!(agent, model)
    recover_or_die!(agent, model)
end

function migrate!(agent, model)
    nodeid = coord2vertex(agent, model)
    d = DiscreteNonParametric(1:model.properties[:ncities], model.properties[:migration_rates][nodeid, :])
    m = rand(d)
    if m ≠ nodeid
        move_agent!(agent, m, model)
    end
end

function transmit!(agent, model)
    agent.status == 1 && return
    prop = model.properties
    rate = if agent.infected < prop[:time_to_detect]
            prop[:Bu][coord2vertex(agent, model)]
        else
            prop[:Bd][coord2vertex(agent, model)]
    end

    d = Poisson(rate)
    n = rand(d)
    n == 0 && return

    for contactID in get_node_contents(agent, model)
        contact = id2agent(contactID, model)
        if contact.status == 1 || (contact.status == 3 && rand() <= prop[:reinfection_probability])
            contact.status = 2
            n -= 1
            if n == 0
                return
            end
        end
    end
end

update!(agent, model) = agent.status == 2 && (agent.infected += 1)

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

# ## Example run
# In the following example we tried to approximate realistic values for the COVID-19 virus.

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


# We will apply this model to a population living in a graph of connected cities which
# looks like this:

using GraphRecipes, Plots, LightGraphs
g = complete_digraph(length(params[:Ns]))
node_weights = params[:Ns]

edgewidthsdict = Dict()
for node in 1:nv(g)
	nbs = neighbors(g, node)
	for nb in nbs
		edgewidthsdict[(node, nb)] = params[:migration_rates][node, nb]
	end
end

edgewidthsf(s, d, w) = edgewidthsdict[(s, d)] * 100

p = graphplot(g,
	node_weights = node_weights,
	edgewidth = edgewidthsf,
	nodeshape = :circle
)

# Here the size of the nodes shows population size.
# Edge thickness shows amount of travel from/to a city.

# We define two useful functions for the data collection
infected(x) = count(i == 2 for i in x)
recovered(x) = count(i == 3 for i in x)

# %% #src
# And finally run the model and collect data
model = model_initiation(;params...)

data_to_collect = Dict(:status => [infected, recovered, length])
data = step!(model, agent_step!, 50, data_to_collect)
data[1:10, :]

# We now plot how quantities evolved in time
using Plots
pyplot()
N = sum(model.properties[:Ns])

x = data.step
p = Plots.plot(x, data[:, Symbol("infected(status)")] / N, label = "infected")
plot!(p, x, data[:, Symbol("recovered(status)")] / N, label = "recovered")
dead = (N .- data[:, Symbol("length(status)")] )/N
plot!(p, x, dead, label = "dead")
xlabel!(p, "steps")
ylabel!(p, "fraction")
p

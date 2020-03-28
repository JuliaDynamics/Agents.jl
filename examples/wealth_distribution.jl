# # Wealth distribution model

# This model is a simple agent-based economy that is modelled according
# to the work of [Dragulescu *et al.*](https://arxiv.org/abs/cond-mat/0211175).
# This work introduces statistical mechanics concepts to study wealth distributions.
# For this reason what we show here is also referred to as "Boltzmann wealth
# distribution" model.

# This model has a version with and without space.
# The rules of the space-less game are quite simple:
# 1. There is a pre-determined number of agents.
# 2. All agents start with one unit of wealth.
# 3. At every step an agent gives 1 unit of wealth (if they have it) to some other agent.

# Even though these are some very simple rules, they can still create the basic
# properties of wealth distributions, e.g. power-laws distributions.

# ## Core structures, space-less
# We start by defining the Agent type and initializing the model.
using Agents
mutable struct WealthAgent <: AbstractAgent
    id::Int
    wealth::Int
end

# Notice that this agent does not have a `pos` field. That is okay, because
# there is no space structure to this example.
# We can also make a very simple [`AgentBasedModel`](@ref) for our model.

function wealth_model(;numagents = 100, initwealth = 1)
    model = ABM(WealthAgent, scheduler=random_activation)
    for i in 1:numagents
        add_agent!(model, initwealth)
    end
    return model
end

model = wealth_model()

# The next step is to define the agent step function
function agent_step!(agent, model)
    agent.wealth == 0 && return # do nothing
    ragent = random_agent(model)
    agent.wealth -= 1
    ragent.wealth += 1
end

# We use `random_agent` as a convenient way to just grab a random agent.
# (this may return the same agent as `agent`, but we don't care in the long run)

# ## Running the space-less model
# Let's do some data collection, running a large model for a lot of time
N = 5
M = 2000
agent_properties = [:wealth]
model = wealth_model(numagents=M)
data = step!(model, agent_step!, N, agent_properties)
data[end-20:end, :]

# What we mostly care about is the distribution of wealth,
# which we can obtain for example by doing the following query:

wealths = filter(x -> x.step == N, data)[!, :wealth]

# and then we can make a histogram of the result.
# With a simple visualization we immediatelly see the power-law distribution:

using UnicodePlots
UnicodePlots.histogram(wealths)

# ## Core structures, with space
# We now expand this model to (in this case) a 2D grid. The rules are the same
# but agents exchange wealth only with their neighbors.
# We therefore have to add a `pos` field as the second field of the agents:

mutable struct WealthInSpace <: AbstractAgent
    id::Int
    pos::NTuple{2, Int}
    wealth::Int
end

function wealth_model_2D(;dims = (25,25), wealth = 1, M = 1000)
  space = GridSpace(dims, periodic = true)
  model = ABM(WealthInSpace, space; scheduler = random_activation)
  for i in 1:M # add agents in random nodes
      add_agent!(model, wealth)
  end
  return model
end

model2D = wealth_model_2D()

# The agent actions are a just a bit more complicated in this example.
# Now the agents can only give wealth to agents that exist on the same or
# neighboring nodes (their "neighbhors").

function agent_step_2d!(agent, model)
    agent.wealth == 0 && return # do nothing
    agent_node = coord2vertex(agent.pos, model)
    neighboring_nodes = node_neighbors(agent_node, model)
    push!(neighboring_nodes, agent_node) # also consider current node
    rnode = rand(neighboring_nodes) # the node that we will exchange with
    available_agents = get_node_contents(rnode, model)
    if length(available_agents) > 0
        random_neighbor_agent = id2agent(rand(available_agents), model)
        agent.wealth -= 1
        random_neighbor_agent.wealth += 1
    end
end

# ## Running the model with space
using Random
Random.seed!(5)
init_wealth = 4
model = wealth_model_2D(;wealth = init_wealth)
agent_properties = [:wealth, :pos]
data = step!(model, agent_step!, 10, agent_properties, when = [1, 5, 10], step0=false)
data[end-20:end, :]

# Okay, now we want to get the 2D spatial wealth distribution of the model.
# That is actually straightforward:
function wealth_distr(data, model, n)
    W = zeros(Int, size(model.space))
    for row in eachrow(filter(r -> r.step == n, data)) # iterate over rows at a specific step
        W[row.pos...] += row.wealth
    end
    return W
end

W1 = wealth_distr(data, model2D, 1)
W5 = wealth_distr(data, model2D, 5)
W10 = wealth_distr(data, model2D, 10)

#

using Plots
Plots.heatmap(W1)

#

Plots.heatmap(W5)

#

Plots.heatmap(W10)

# What we see is that wealth gets more and more localized.

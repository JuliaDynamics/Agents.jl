# # Wealth distribution model

# This model is a simple agent-based economy that is taken modelled according
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
mutable struct WealthyAgent <: AbstractAgent
    id::Int
    wealth::Int
end

# Notice that this agent does not have a `pos` field. That is okay, because
# there is no space structure to this example.
# We can also make a very simple [`AgentBasedModel`](@ref) for our model.
# Because it is pre-determined how many agents the model we have, we can
# even make it a parameter of the model for easy access.

function wealth_model(numagents = 100)
    p = (n = numagents,)
    model = ABM(WealthyAgent, scheduler=random_activation, properties = p)

    for i in 1:numagents
        add_agent!(model, 1) # 1 is the initial wealth!
    end
    return model
end

model = wealth_model(100)

# The next step is to define the agent step function
function agent_step!(agent::AbstractAgent, model::ABM)
    agent.wealth == 0 && return # do nothing
    ragent = random_agent(model)
    agent.wealth -= 1
    ragent.wealth += 1
end

# We use `random_agent` as a convenient way to just grab a random agent.
# (this may return the same agent as `agent`, but we disregard it as noise)

# ## Running the space-less model
# Let's do some data collection, running a large model for a lot of time
N = 50
M = 5000
when = 1:(N÷5):N
agent_properties = [:wealth]
model = wealth_model(M)
data = step!(model, agent_step!, N, agent_properties, when=when)

# What we mostly care about is the distribution of wealth.
# Let's see how this changes at different times:

using PyPlot
figure()
for i in 2:size(data)[2]
    wealths = data[:, i]
    plt.hist(wealths, bins=0:(maximum(wealths)+1), alpha = 0.5,
    label = "n=")
end
legend()
gcf()

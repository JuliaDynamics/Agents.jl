# # Wealth distribution model

# This model is a simple agent-based economy that is modelled according
# to the work of [Dragulescu *et al.*](https://arxiv.org/abs/cond-mat/0211175).
# This work introduces statistical mechanics concepts to study wealth distributions.
# What we show here is also referred to as "Boltzmann wealth distribution" model.

# This model has a version with and without space.
# The rules of the space-less game are quite simple:
# 1. There is a pre-determined number of agents.
# 2. All agents start with one unit of wealth.
# 3. At every step an agent gives 1 unit of wealth (if they have it) to some other agent.

# Even though this rule-set is simple, it can still recreate the basic
# properties of wealth distributions, e.g. power-laws distributions.

# ## Core structures: space-less
# We start by defining the Agent type and initializing the model.
using Agents
using Random # hide
Random.seed!(5) # hide

mutable struct WealthAgent <: AbstractAgent
    id::Int
    wealth::Int
end

# Notice that this agent does not have a `pos` field. That is okay, because
# there is no space structure to this example.
# We can also make a very simple [`AgentBasedModel`](@ref) for our model.

function wealth_model(; numagents = 100, initwealth = 1)
    model = ABM(WealthAgent, scheduler = random_activation)
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
nothing # hide

# We use `random_agent` as a convenient way to just grab a second agent.
# (this may return the same agent as `agent`, but we don't care in the long run)

# ## Running the space-less model
# Let's do some data collection, running a large model for a lot of time
N = 5
M = 2000
adata = [:wealth]
model = wealth_model(numagents = M)
data, _ = run!(model, agent_step!, N; adata)
data[(end-20):end, :]

# What we mostly care about is the distribution of wealth,
# which we can obtain for example by doing the following query:

wealths = filter(x -> x.step == N - 1, data)[!, :wealth]

# and then we can make a histogram of the result.
# With a simple visualization we immediately see the power-law distribution:

using CairoMakie, AbstractPlotting
CairoMakie.activate!() # hide
hist(
    wealths;
    bins = collect(0:9),
    width = 1,
    color = cgrad(:viridis)[28:28:256],
    figure = (resolution = (600, 400),),
)

# ## Core structures: with space
# We now expand this model to (in this case) a 2D grid. The rules are the same
# but agents exchange wealth only with their neighbors.

# It is also available from the `Models` module as [`Models.wealth_distribution`](@ref).

# We therefore have to add a `pos` field as the second field of the agents:

mutable struct WealthInSpace <: AbstractAgent
    id::Int
    pos::NTuple{2,Int}
    wealth::Int
end

function wealth_model_2D(; dims = (25, 25), wealth = 1, M = 1000)
    space = GridSpace(dims, periodic = true)
    model = ABM(WealthInSpace, space; scheduler = random_activation)
    for i in 1:M # add agents in random positions
        add_agent!(model, wealth)
    end
    return model
end

model2D = wealth_model_2D()

# The agent actions are a just a bit more complicated in this example.
# Now the agents can only give wealth to agents that exist on the same or
# neighboring positions (their "neighbors").

function agent_step_2d!(agent, model)
    agent.wealth == 0 && return # do nothing
    neighboring_positions = collect(nearby_positions(agent.pos, model))
    push!(neighboring_positions, agent.pos) # also consider current position
    rpos = rand(model.rng, neighboring_positions) # the position that we will exchange with
    available_ids = ids_in_position(rpos, model)
    if length(available_ids) > 0
        random_neighbor_agent = model[rand(model.rng, available_ids)]
        agent.wealth -= 1
        random_neighbor_agent.wealth += 1
    end
end
nothing # hide

# ## Running the model with space
init_wealth = 4
model = wealth_model_2D(; wealth = init_wealth)
adata = [:wealth, :pos]
data, _ = run!(model, agent_step!, 10; adata = adata, when = [1, 5, 9])
data[(end-20):end, :]

# Okay, now we want to get the 2D spatial wealth distribution of the model.
# That is actually straightforward:

function wealth_distr(data, model, n)
    W = zeros(Int, size(model.space))
    for row in eachrow(filter(r -> r.step == n, data)) # iterate over rows at a specific step
        W[row.pos...] += row.wealth
    end
    return W
end

function make_heatmap(W)
    figure = Figure(; resolution = (600, 450))
    hmap_l = figure[1, 1] = Axis(figure)
    hmap = heatmap!(hmap_l, W; colormap = cgrad(:default))
    cbar = figure[1, 2] = Colorbar(figure, hmap; width = 30)
    return figure
end

W1 = wealth_distr(data, model2D, 1)
make_heatmap(W1)
#

W5 = wealth_distr(data, model2D, 5)
make_heatmap(W5)
#

W10 = wealth_distr(data, model2D, 9)
make_heatmap(W10)

# What we see is that wealth gets more and more localized.

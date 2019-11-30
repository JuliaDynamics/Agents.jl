```@meta
EditURL = "<unknown>/../Agents/examples/wealth_distribution.jl"
```

# Wealth distribution model

This model is a simple agent-based economy that is modelled according
to the work of [Dragulescu *et al.*](https://arxiv.org/abs/cond-mat/0211175).
This work introduces statistical mechanics concepts to study wealth distributions.
For this reason what we show here is also referred to as "Boltzmann wealth
distribution" model.

This model has a version with and without space.
The rules of the space-less game are quite simple:
1. There is a pre-determined number of agents.
2. All agents start with one unit of wealth.
3. At every step an agent gives 1 unit of wealth (if they have it) to some other agent.

Even though these are some very simple rules, they can still create the basic
properties of wealth distributions, e.g. power-laws distributions.

## Core structures, space-less
We start by defining the Agent type and initializing the model.

```@example wealth_distribution
using Agents
mutable struct WealthAgent <: AbstractAgent
    id::Int
    wealth::Int
end
```

Notice that this agent does not have a `pos` field. That is okay, because
there is no space structure to this example.
We can also make a very simple [`AgentBasedModel`](@ref) for our model.

```@example wealth_distribution
function wealth_model(;numagents = 100, initwealth = 1)
    model = ABM(WealthAgent, scheduler=random_activation)
    for i in 1:numagents
        add_agent!(model, initwealth)
    end
    return model
end

model = wealth_model()
```

The next step is to define the agent step function

```@example wealth_distribution
function agent_step!(agent, model)
    agent.wealth == 0 && return # do nothing
    ragent = random_agent(model)
    agent.wealth -= 1
    ragent.wealth += 1
end
```

We use `random_agent` as a convenient way to just grab a random agent.
(this may return the same agent as `agent`, but we don't care in the long run)

## Running the space-less model
Let's do some data collection, running a large model for a lot of time

```@example wealth_distribution
N = 5
M = 2000
agent_properties = [:wealth]
model = wealth_model(numagents=M)
data = step!(model, agent_step!, N, agent_properties)
```

What we mostly care about is the distribution of wealth,
which we can obtain for example by doing the following query:

```@example wealth_distribution
wealths = filter(x -> x.step == N, data)[!, :wealth]
```

and then we can make a histogram of the result.
With a simple visualization we immediatelly see the power-law distribution:

```@example wealth_distribution
using UnicodePlots
UnicodePlots.histogram(wealths)
```

## Core structures, with space
We now expand this model to (in this case) a 2D grid. The rules are the same
but agents exchange wealth only with their neighbors.
We therefore have to add a `pos` field as the second field of the agents:

```@example wealth_distribution
mutable struct WealthInSpace <: AbstractAgent
    id::Int
    pos::NTuple{2, Int}
    wealth::Int
end

function wealth_model_2D(;dims = (25,25), wealth = 1, M = 1000)
  space = Space(dims, periodic = true)
  model = ABM(WealthInSpace, space; scheduler = random_activation)
  for i in 1:M # add agents in random nodes
      add_agent!(model, wealth)
  end
  return model
end

model2D = wealth_model_2D()
```

The agent actions are a just a bit more complicated in this example.
Now the agents can only give wealth to agents that exist on the same or
neighboring nodes (their "neighbhors").

```@example wealth_distribution
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
```

## Running the model with space

```@example wealth_distribution
using Random
Random.seed!(5)
init_wealth = 4
model = wealth_model_2D(;wealth = init_wealth)
agent_properties = [:wealth]
data = step!(model, agent_step!, 10, agent_properties, when = [1, 5, 10], step0=false)
```

Okay, now we want to get the 2D spatial wealth distribution of the model.
That is actually straightforward:

```@example wealth_distribution
function wealth_distr(data, model, n)
    W = zeros(Int, size(model.space))
    for row in eachrow(filter(r -> r.step == n, data)) # iterate over rows at a specific step
        W[id2agent(row.id, model).pos...] += row.wealth
    end
    return W
end

W1 = wealth_distr(data, model2D, 1)
```

```@example wealth_distribution
W5 = wealth_distr(data, model2D, 5)
```

```@example wealth_distribution
W10 = wealth_distr(data, model2D, 10)
```

What we see is that wealth gets more and more localized.

*This page was generated using [Literate.jl](https://github.com/fredrikekre/Literate.jl).*


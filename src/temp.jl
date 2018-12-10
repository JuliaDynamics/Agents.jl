#= Lets write a simple model

The tutorial model is a very simple simulated agent-based economy, drawn from econophysics and presenting a statistical mechanics approach to wealth distribution [Dragulescu2002]_. The rules of our tutorial model:

* There are some number of agents.
* All agents begin with 1 unit of money.
* At every step of the model, an agent gives 1 unit of money (if they have it) to some other agent.

Despite its simplicity, this model yields results that are often unexpected to those not familiar with it. For our purposes, it also easily demonstrates Mesa’s core features.
=#


# 1 define agent type

mutable struct MyAgent <: AbstractAgent
  id::Integer
  wealth::Integer
end

# 2 define a model

mutable struct MyModel4 <: AbstractModel
  grid
  agents::Array{AbstractAgent}  # a list of agents
  scheduler::Function
end

# 2.1 instantiate the model
mygrid = grid2D(50, 50)
agents = [MyAgent(i, 1) for i in 1:100]
model = MyModel4(mygrid, agents, random_activation)

# 3 define what the agent does at each step

function agent_step!(agent::AbstractAgent, model::AbstractModel)
  if agent.wealth == 0
    return
  else
    agent2 = model.agents[rand(1:nagents(model))]
    agent.wealth -= 1
    agent2.wealth += 1
  end
end

# Run the model 10 steps (only agent activations)
step!(agent_step!, model, 10)

# Plot some model results

agents_plots_complete([:wealth, :hist], model)

# you may add one more function to the step!() function. This new function applies after the agent_step!(). Such functions can apply to change the model, e.g. change the number of individuals or change to the environment. Therefore, such models should only accept the model as their argument. TODO


# TODO: run replicates of the model
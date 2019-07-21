# Schelling's segregation model

## Agents.jl's architecture

Agents.jl is composed of components for building models, building and managing space structures, collecting data, running batch simulations, and data visualization.

For building any ABM, users have to define at least three objects and one function (Fig. 1). Agents.jl's tools manage the rest of the path to producing data and visualizations (Fig. 1). We now demonstrate Agents.jl's architecture and features through building Schelling's segregation model.

![Fig. 1. __Path from building a model to gaining information from the model using Agents.jl.__ The box in cyan is what the user has to provide and the boxes in green are what Agents.jl provides.](agentscomponents.png)

We implement the following definition of Schelling's segregation model:

* Agents are of two kind (0 or 1).
* Each agent has eight neighbors (Moore neighborhoods).
* If an agent is in the same group with at least three neighbors, then it is happy.
* If an agent is unhappy, it keeps moving to new locations until it is happy.

### Defining a model object

Building models using Agents.jl, we always start by defining three basic objects: one for the model, one for the the agents and one for the space.

A model object is a subtype of `AbstractModel`. Making the model a subtype of `AbstractModel` will make Agents.jl methods available to the model. It needs to have the following three fields: `scheduler`, `space`, and `agents`. We can add more fields if needed.

The `scheduler` field accepts a function that defines the order with which agents will activate at each step. The function should accept the model object as its input and return a list of agent indices. Agents.jl provides three schedulers: `as_added` to activate agents as they have been added to the model, `random_activation` to activate agents randomly, and `partial_activation` to activate only a random fraction of agents at each step.

```julia
using Agents

mutable struct SchellingModel <: AbstractModel  # A model object should always be a subtype of AbstractModel
 space::AbstractSpace  # A space object, which is a field of the model object is always subtype of AbstractSpace
 agents::Array{AbstractAgent}  # a list of agents
 scheduler::Function
 min_to_be_happy::Integer  # minimum number of neighbors to be of the same kind so that they are happy
end
```

It is best to make any model parameter a field of the model object. We add the minimum number of neighbors of the same kind for an agent to be happy as a field of the model (`min_to_be_happy`). 

### Defining an agent object

Next, we define an agent object. Agent objects are subtypes of `AbstractAgent` and should always have the following fields: `id` which stores agent IDs as integers, and `pos` to store each agent's position. Agent positions can be tuple of integers as coordinates of nodes of a grid (1D, 2D or 3D). Positions can also be integers only, referring to the number of a node in an irregular network.

```julia
mutable struct SchellingAgent <: AbstractAgent # An agent object should always be a subtype of AbstractAgent
 id::Integer
 pos::Tuple{Integer, Integer}
 mood::Bool # true is happy and false is unhappy
 group::Integer
end
```

We add two more fields for this model, namely a `mood` field which will store `true` for a happy agent and `false` for an unhappy one, and an `group` field which stores `0` or `1` representing two groups.

### Defining a space object

Finally, we define a space object. The space object is always a subtype of `AbstractSpace` and should have at least the following three fields. First, a `space` field which holds the spatial structure of the model. Agents.jl uses network structures from the [LightGraphs package](https://github.com/JuliaGraphs/LightGraphs.jl) to represent space.  It provides 1D, 2D and 3D grids. The grids may have periodic boundary conditions, meaning nodes on the left and right edges and top and bottom edges are connected to one another. Furthermore, the nodes on a grid may have von Neumann neighborhoods, i.e. only connect to their orthogonal neighbors, or Moore neighborhoods, i.e. connect to their orthogonal and diagonal neighbors. Users may also provide arbitrary networks as their model's spatial structure.

The second field of the space object is the `dimensions` of the grid or network. Lastly, every space object should have an `agent_positions` field. This field is an array of arrays for each node of the network. Each inner array will record the ID of the agents on that position. Agents.jl keeps the position of agents in two places. One in each agent's object and one in the `agent_positions`.

```julia
mutable struct MyGrid <: AbstractSpace # A space object should always be a subtype of AbstractSpace
 dimensions::Tuple{Integer, Integer}
 space
 agent_positions::Array  # an array of arrays for each grid node
end
```

### Instantiating the model

Now that we have defined the basic objects, we should instantiate the model. We put the model instantiation in a function so that it will be easy to recreate the model and change its parameters.

```julia
function instantiate_model(; numagents=320, griddims=(20, 20), min_to_be_happy=3)
 agent_positions = [Array{Integer}(undef, 0) for i in 1:gridsize(griddims)]  # 1
 mygrid = MyGrid(griddims, grid(griddims, false, true), agent_positions)  # 2
 model = SchellingModel(mygrid, AbstractAgent[], random_activation, min_to_be_happy)  # 3
  
 agents = vcat(
  [SchellingAgent(i, (1,1), false, 0) for i in 1:(numagents/2)], [SchellingAgent(i, (1,1), false, 1) for i in (numagents/2)+1:numagents])  # 4

 for agent in agents 
  add_agent_single!(agent, model)  # 5
 end
 return model
end
```

Explanations below correspond to the numbered lines in the code snippet above:

* creates an array of empty arrays as many as there are agents.
* creates a 2D grid with nodes that have Moore neighborhoods. The grid does not have periodic edges.
* instantiates the model. It uses an empty array for `agents`.
* creates an array of agents with two different groups. All agents have a temporary coordinate of (1, 1).
* adds agents to random nodes in space and to the `agents` array in the model object. `add_agent_single!` ensures that there are no more than one agent per node.

### Defining a step function

The last step of building our ABM is defining a _step_ function. Any ABM model should have at least one and at most two step functions. An _agent step function_ is always required. Such an agent step function defines what happens to an agent when it activates. Sometimes we will need also need a function that changes all agents at once, or changes a model property. In such cases, we can also provide a _model step function_.

An agent step function should only accept two arguments, the first of which an agent object and the second of which a model object. The model step function should accept only one argument, that is the model object. It is possible to only have a _model step function_, in which case users have to use the built-in `dummystep` as the _agent step function_.

```julia
function agent_step!(agent, model)
 if agent.mood == true
  return
 end
 while agent.mood == false
  neighbor_cells = node_neighbors(agent, model)
  same = 0
  for nn in neighbor_cells
   nsid = get_node_contents(nn, model)
   if length(nsid) == 0
    continue
   else
    nsid = nsid[1]
   end
   ns = model.agents[nsid].group
   if ns == agent.group
    same += 1
   end
  end
  if same >= model.min_to_be_happy
   agent.mood = true
  else
   # move
   move_agent_single!(agent, model)
  end
 end
end
```

For building this implementation of Schelling's segregation model, we only need an agent step function.

When an agent activates, it follows the following process:

* If the agent is already happy, it does not do anything.
* If it is not happy, it counts the number of its neighbors that are from the same group.
* If this count is equal to `min_to_be_happy`, the agent will be happy...
* ...otherwise the agent will keep moving to random empty nodes on the grid until it is happy.

For doing these operations, we used some of the built-in functions of Agents.jl, such as `node_neighbors` that returns the neighboring nodes of the node on which the agent resides, `get_node_contents` that returns the IDs of the agents on a given node, and `move_agent_single!` which moves agents to random empty nodes on the grid. A full list of built-in functions and their explanations are available in the online manual.

### Running the model

We can run each step of the function using the built-in `step!` function. This will update the agents and the model as defined by the `agent_step!` function.

```julia
model = instantiate_model(numagents=200, griddims=(20,20), min_to_be_happy=2)
step!(agent_step!, model)  # run the model one step or
step!(agent_step!, model, 3)  # run the model multiple (3) steps
```

### Running the model and collecting data

There is however a more efficient way to run the model and collect data. We can use the same `step!` function with more arguments to run multiple steps and collect values of our desired fields from every agent and put these data in a `DataFrame` object.

```julia
model = instantiate_model(numagents=200, griddims=(20,20), min_to_be_happy=2)
agent_properties = [:pos, :mood, :group]
steps_to_collect_data = collect(1:4)
data = step!(agent_step!, model, 4, agent_properties, steps_to_collect_data)
```julia

`agent_properties` is an array of `Symbols` for the agent fields that we want to collect. `steps_to_collect_data` specifies at which steps data should be collected.

### Visualizing the data

We can use the `visualize_2D_agent_distribution` function to plot the distribution of agents on a 2D grid at every generation (Fig. 1):

```julia
for i in 1:4
 visualize_2D_agent_distribution(data, model, Symbol("pos_$i"), types=Symbol("group_$i"), savename="step_$i", cc=Dict(0=>"blue", 1=>"red"))
end
```

The first and second arguments of the `visualize_2D_agent_distribution` are the `data` and the `model` objects. The third argument is the column name in `data` that has the position of each agent. The fourth argument is the column name in `data` that stores agents'  groups. `savename` is the name of the plot file. `cc` is a dictionary that defines the colors of each agent group.

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

"""
AbstractModel type for the Schelling Model

Object should always be a subtype of AbstractModel.
"""
mutable struct SchellingModel{T<:Integer, Y<:AbstractArray,
                              Z<:AbstractSpace} <: AbstractModel 

  "A field of the model for a space object, always a subtype of AbstractSpace."
  space::Z
  "A list of agents."
  agents::Y
  "A field for the scheduler function."
  scheduler::Function
  "The minimum number of neighbors for agent to be happy."
  min_to_be_happy::T
end
```

It is best to make any model parameter a field of the model object. We add the minimum number of neighbors of the same kind for an agent to be happy as a field of the model (`min_to_be_happy`). 

### Defining an agent object

Next, we define an agent object. Agent objects are subtypes of `AbstractAgent` and should always have the following fields: `id` which stores agent IDs as integers, and `pos` to store each agent's position. Agent positions can be tuple of integers as coordinates of nodes of a grid (1D, 2D or 3D). Positions can also be integers only, referring to the number of a node in an irregular network.

```julia
"""
AbstractAgent type for the Schelling Agent

Object should always be a subtype of AbstractAgent.
"""
mutable struct SchellingAgent{T<:Integer} <: AbstractAgent
  "The identifier number of the agent."
  id::T
  "The x, y location of the agent."
  pos::Tuple{T, T}
  """
  Whether or not the agent is happy with cell.

  Where true is "happy" and false is "unhappy"

  """
  mood::Bool
  "The group of the agent, determines mood as it interacts with neighbors."
  group::T
end
```

We add two more fields for this model, namely a `mood` field which will store `true` for a happy agent and `false` for an unhappy one, and an `group` field which stores `0` or `1` representing two groups.

### Defining a space object

Finally, we define a space object. The space object is always a subtype of `AbstractSpace` and should have at least the following three fields. First, a `space` field which holds the spatial structure of the model. Agents.jl uses network structures from the [LightGraphs package](https://github.com/JuliaGraphs/LightGraphs.jl) to represent space.  It provides 1D, 2D and 3D grids. The grids may have periodic boundary conditions, meaning nodes on the left and right edges and top and bottom edges are connected to one another. Furthermore, the nodes on a grid may have von Neumann neighborhoods, i.e. only connect to their orthogonal neighbors, or Moore neighborhoods, i.e. connect to their orthogonal and diagonal neighbors. Users may also provide arbitrary networks as their model's spatial structure.

The second field of the space object is the `dimensions` of the grid or network. Lastly, every space object should have an `agent_positions` field. This field is an array of arrays for each node of the network. Each inner array will record the ID of the agents on that position. Agents.jl keeps the position of agents in two places. One in each agent's object and one in the `agent_positions`.

```julia
"The space of the experiment."
mutable struct MyGrid{T<:Integer, Y<:AbstractArray} <: AbstractSpace
  "Dimensions of the grid."
  dimensions::Tuple{T, T}
  "The space type."
  space::SimpleGraph
  "An array of arrays for each grid node."
  agent_positions::Y  
end
```

### Instantiating the model

Now that we have defined the basic objects, we should instantiate the model. We put the model instantiation in a function so that it will be easy to recreate the model and change its parameters.

```julia
"Function to instantiate the model."
function instantiate_model(;numagents=320, griddims=(20, 20), min_to_be_happy=3)

  # 1) Creates an array of empty arrays as many as there are agents.
  agent_positions = [Int64[] for i in 1:gridsize(griddims)]

  # 2) Use MyGrid to create a grid from griddims and agent_positions using the
  #    grid function.
  mygrid = MyGrid(griddims, grid(griddims, false, true), agent_positions)

  # 3) Instantiate the model using mygrid, the SchellingAgent type, the
  #    random_activation function from Agents.jl and the
  #    argument min_to_be_happy.
  model = SchellingModel(mygrid, SchellingAgent[], random_activation,
                         min_to_be_happy) 

  # 4) Create a 1-dimension list of agents, balanced evenly between group 0
  #    and group 1.
  agents = vcat(
    [SchellingAgent(Int(i), (1,1), false, 0) for i in 1:(numagents/2)],
    [SchellingAgent(Int(i), (1,1), false, 1) for i in (numagents/2)+1:numagents]
  )

  # 5) Add the agents to the model.
  for agent in agents
    # Use add_agent_single (from Agents.jl) to add the agents to the grid at
    # random locations.
    add_agent_single!(agent, model)
  end
  return model
end
```

Explanations below correspond to the numbered lines in the code snippet above:

1. Creates an array of empty arrays as many as there are agents.
2. Creates a 2D grid with nodes that have Moore neighborhoods. The grid does not have periodic edges.
3. Instantiates the model. It uses an empty array for `agents`.
4. Creates an array of agents with two different groups. All agents have a temporary coordinate of (1, 1).
5. Adds agents to random nodes in space and to the `agents` array in the model object. `add_agent_single!` ensures that there are no more than one agent per node.

### Defining a step function

The last step of building our ABM is defining a _step_ function. Any ABM model should have at least one and at most two step functions. An _agent step function_ is always required. Such an agent step function defines what happens to an agent when it activates. Sometimes we will need also need a function that changes all agents at once, or changes a model property. In such cases, we can also provide a _model step function_.

An agent step function should only accept two arguments, the first of which an agent object and the second of which a model object. The model step function should accept only one argument, that is the model object. It is possible to only have a _model step function_, in which case users have to use the built-in `dummystep` as the _agent step function_.

```julia
"Move a single agent until a satisfactory location is found."
function agent_step!(agent, model)
  if agent.mood == true
    return
  end
  while agent.mood == false
    neighbor_cells = node_neighbors(agent, model)
    count_neighbors_same_group = 0

    # For each neighbor, get group and compare to current agent's group...
    # ...and increment count_neighbors_same_group as appropriately.  
    for neighbor_cell in neighbor_cells
      node_contents = get_node_contents(neighbor_cell, model)
      # Skip iteration if the node is empty.
      if length(node_contents) == 0
        continue
      else
        # Otherwise, get the first agent in the node...
        node_contents = node_contents[1]
      end
      # ...and increment count_neighbors_same_group if the neighbor's group is
      # the same.
      neighbor_agent_group = model.agents[node_contents].group
      if neighbor_agent_group == agent.group
        count_neighbors_same_group += 1
      end
    end

    # After evaluating and adding up the groups of the neighbors, decide
    # whether or not to move the agent.
    # If count_neighbors_same_group is at least the min_to_be_happy, set the
    # mood to true. Otherwise, move the agent using move_agent_single.
    if count_neighbors_same_group >= model.min_to_be_happy
      agent.mood = true
    else
      move_agent_single!(agent, model)
    end
  end
end
```

For the purpose of this implementation of Schelling's segregation model, we only need an agent step function.

When an agent activates, it follows the following process:

* If the agent is already happy, it does not do anything.
* If it is not happy, it counts the number of its neighbors that are from the same group.
* If this count is equal to `min_to_be_happy`, the agent will be happy...
* ...otherwise the agent will keep moving to random empty nodes on the grid until it is happy.

For doing these operations, we used some of the built-in functions of Agents.jl, such as `node_neighbors` that returns the neighboring nodes of the node on which the agent resides, `get_node_contents` that returns the IDs of the agents on a given node, and `move_agent_single!` which moves agents to random empty nodes on the grid. A full list of built-in functions and their explanations are available in the online manual.

### Running the model

We can run each step of the function using the built-in `step!` function. This will update the agents and the model as defined by the `agent_step!` function.

```julia
# Instantiate the model with 370 agents on a 20 by 20 grid. 
model = instantiate_model(numagents=370, griddims=(20,20), min_to_be_happy=3)
step!(agent_step!, model)  # Run the model one step...
step!(agent_step!, model, 3)  # ...run the model multiple (3) steps.
```

### Running the model and collecting data

There is however a more efficient way to run the model and collect data. We can use the same `step!` function with more arguments to run multiple steps and collect values of our desired fields from every agent and put these data in a `DataFrame` object.

```julia
# Instantiate the model with 370 agents on a 20 by 20 grid. 
model = instantiate_model(numagents=370, griddims=(20,20), min_to_be_happy=3)
# An array of Symbols for the agent fields that are to be collected.
agent_properties = [:pos, :mood, :group]
# Specifies at which steps data should be collected.
steps_to_collect_data = collect(1:2)
# Use the step function to run the model and collect data into a DataFrame.
data = step!(agent_step!, model, 2, agent_properties, steps_to_collect_data)
```

`agent_properties` is an array of [`Symbols`](https://pkg.julialang.org/docs/julia/THl1k/1.1.1/manual/metaprogramming.html#Symbols-1) for the agent fields that we want to collect. `steps_to_collect_data` specifies at which steps data should be collected.

### Visualizing the data

We can use the `visualize_2D_agent_distribution` function to plot the distribution of agents on a 2D grid at every generation (Fig. 1):

```julia
# Use visualize_2D_agent_distribution to plot distribution of agents at every step.
for i in 1:2
  visualize_2D_agent_distribution(data, model, Symbol("pos_$i"),
  types=Symbol("group_$i"), savename="step_$i", cc=Dict(0=>"blue", 1=>"red"))
end
```

The first and second arguments of the `visualize_2D_agent_distribution` are the `data` and the `model` objects. The third argument is the column name in `data` that has the position of each agent. The fourth argument is the column name in `data` that stores agents'  groups. `savename` is the name of the plot file. `cc` is a dictionary that defines the colors of each agent group.

# Tutorial

## Agents.jl's basic usage

Agents.jl is composed of components for building models, building and managing space structures, collecting data, running batch simulations, and data visualization.

Agents.jl structures simulations in three components: a _model_ component that keeps all model-level variables and data, an _agent_ component that keeps all agent-level variables and data, and a _space_ component that represents the space where the agents live.

For building any ABM, users have to define at least the following four quantities:
1. A `struct` for the model.
2. A `struct` for the agents.
3. A `Space` instance.  
4. A stepping function that controls how the agents and the model evolve.

With these, Agents.jl's tools manage the rest of the path to producing and processing data, as well as visualizations (Fig. 1).

![Fig. 1. __Path from building a model to gaining information from the model using Agents.jl.__ The box in cyan is what the user has to provide and the boxes in green are what Agents.jl provides.](agentscomponents.png)

### The model
```@docs
AbstractModel
```
The model type may not necessarily be a mutable type, it depends on your problem.
## The space
Under the hood, all spaces are represented by a graph from LightGraphs.jl.
However, if your space is a regular grid then there is some additional functionality that allows converting graph nodes to coordinates on the multidimensional grid.

Regardless, in every case you initialize your space by calling `Space`:
```@docs
Space
```
### The agent
```@docs
AbstractAgent
```
The agent type **must** be mutable. Once an Agent is created it can be added to a model using e.g.
```@docs
add_agent!
add_agent_single!
```
Then, the agent can interact with the model and the space futher by using
```@docs
move_agent!
move_agent_single!
kill_agent!
```
For more functions visit the [Built-in functions](@ref) page.

### The stepping function
Any ABM model should have at least one and at most two step functions.
An _agent step function_ is always required.
Such an agent step function defines what happens to an agent when it activates.
Sometimes we also need a function that changes all agents at once, or changes a model property. In such cases, we can also provide a _model step function_.

An agent step function should only accept two arguments: first, an agent object, and second, a model object.

The model step function should accept only one argument, that is the model object.
To use only a model step function, users can use the built-in `dummystep` as the agent step function.

### Running the model & collecting data

After the basic types and functions are defined, we can run the model using the built-in `step!` function. This will update the agents and the model as defined by the agent and model stepping functions.
In addition, by providing keywords to `step!`, it is also possible to collect and process data while the model evolves.
```@docs
Agents.step!
```


## Example: Schelling's segregation model

We now demonstrate Agents.jl's architecture and features through building the following definition of Schelling's segregation model:

* Agents belong to one of two groups (0 or 1).
* The agents leave in a two-dimensional Moore grid (8 neighbors per node).
* If an agent is in the same group with at least three neighbors, then it is happy.
* If an agent is unhappy, it keeps moving to new locations until it is happy.

### Defining the agent type
```@example schelling
mutable struct SchellingAgent <: AbstractAgent
  id::Int # The identifier number of the agent
  pos::Tuple{Int,Int} # The x, y location of the agent
  mood::Bool # whether the agent is happy in its node. (true = happy)
  group::Int # The group of the agent,
             # determines mood as it interacts with neighbors
end
```
Notice that the position of this Agent type is a `Tuple{Int,Int}` because we will use a grid `Space`.

We added two more fields for this model, namely a `mood` field which will store `true` for a happy agent and `false` for an unhappy one, and an `group` field which stores `0` or `1` representing two groups.


### Defining the model type
```@example schelling
using Agents

mutable struct SchellingModel{S, F} <: AbstractModel
  scheduler::F
  space::S
  agents::Vector{SchellingAgent}
  "A field for the scheduler function."
  min_to_be_happy::Int # minimum number of neighbors for agent to be happy
end
```

We add the minimum number of neighbors of the same kind for an agent to be happy as a field of the model (`min_to_be_happy`).

### Instantiating the model

Now that we have defined the basic structs, we should instantiate the model.
We put the model instantiation in a function so that it will be easy to recreate the model and change its parameters.

For the schedulling function in this example we will use the provided [`random_activation`](@ref).

```@example schelling
"Function to instantiate the model."
function instantiate(;numagents=320, griddims=(20, 20), min_to_be_happy=3)

  space = Space(griddims, false, true) # make a Moore grid
  # use random_activation function from Agents.jl and the argument min_to_be_happy
  # give the model an empty list of agents, as they will be added incrementally
  model = SchellingModel(random_activation, space, SchellingAgent[], min_to_be_happy)

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

Finally, we define a _step_ function to determine what happens to an agent when activated.

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

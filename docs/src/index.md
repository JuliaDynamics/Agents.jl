# Agents.jl Documentation

![Agents.jl](https://github.com/JuliaDynamics/JuliaDynamics/blob/master/videos/agents/agents_logo.gif?raw=true)

!!! info "JuliaDynamics"
    Agents.jl is part of [JuliaDynamics](https://juliadynamics.github.io/JuliaDynamics/), check out our [website](https://juliadynamics.github.io/JuliaDynamics/) for more cool stuff!


Agents.jl is a [Julia](https://julialang.org/) framework for agent-based modeling (ABM).
To get started, please read the [Tutorial](@ref) page.

An agent-based (or individual-based) model is a computational simulation of autonomous agents that react to their environment (including other agents) given a predefined set of rules [[1](http://doi.org/10.1016/j.ecolmodel.2006.04.023)]. ABM has gained wide usage in a variety of research disciplines. One reason for its popularity is that it allows relaxing many simplifying assumptions usually made by mathematical models. Relaxing such assumptions of a "perfect world" can change a model's behavior [[2](http://doi.org/10.1038/460685a)]. ABM is specifically an important tool for studying complex systems where a system's behavior cannot be predicted and has to be explored (see the "Why we need ABM" section for detailed examples).

Agent.jl provides a structure and components for quickly implementing agent-based models, run them in batch, collect data, and visualize them. To that end, it provides the following functionalities:

* Default grids to run the simulation, including simple or toroidal 1D grids, simple or toroidal regular rectangular and triangular 2D grids, and simple or toroidal regular cubic 3D grids with von Neumann or Moore neighborhoods. Users can use their defined graphs too.
* Automatic data collection in a `DataFrame` at desired intervals.
* Exploring the simulation results interactively in [Data Voyager 2](https://github.com/vega/voyager).
* Batch running and batch data collection
* Visualize agent distributions on grids

Many agent-based modeling frameworks have been constructed to ease the process of building and analyzing ABMs (see [here](http://dx.doi.org/10.1016/j.cosrev.2017.03.001) for a review). Notable examples are [NetLogo](https://ccl.northwestern.edu/netlogo/), [Repast](https://repast.github.io/index.html), [MASON](https://journals.sagepub.com/doi/10.1177/0037549705058073), and [Mesa](https://github.com/projectmesa/mesa).

Implementing an ABM framework in Julia has several advantages:
1. Using a general purpose programming language instead of a custom scripting language, such as NetLogo's, removes a learning step and provides a single environment for building the models and analyzing their results.
2. Julia has a rich ecosystem for data analysis and visualization, implemented and maintained independently from Agents.jl.
3. Julia is easier-to-use than Java (used for Repast and MASON), and provides a REPL (Read-Eval-Print-Loop) environment to build and analyze models interactively.
4. Unlike Python (used for Mesa), Julia is fast to run. This is a crucial criterion for models that require considerable computations.

Agents.jl provides users with core components that make it easy to build ABMs, run them in batch, collect model outputs, and visualize the results. Briefly, the framework eases the following tasks for the user, and is at the same time flexible enough to allow implementation of almost any ABM.

* __Schedulers__: users can choose from a range of activation regimes, i.e. the order with which agents activate, or implement a custom one.
* __Spatial structures__: the framework implements 1D, 2D, and 3D grids which can optionally have periodic boundary conditions, meaning that edges of a grid connect to their opposite edges. An agent exiting from one edge enters the grid from the opposite edge. Moreover, users can construct irregular networks as the space where the agents live.
* __Data collection__: users only specify the kind of data they need and the framework automatically collects them in a table. The collected data are then ready to be analyzed and visualized.
* __Batch run__: in agent-based modeling, we can rarely make conclusions from single simulation runs. Instead we run many replicates of a simulation and observe the mean behavior of the system. Agents.jl automates running simulation replicates and collecting and aggregating their results.
* __Visualization__ users can create custom plots interactively from the simulation outputs using the [Data Voyager](https://github.com/vega/voyager) platform. Furthermore, they can visualize agent distributions on 2D grids.

Agents.jl is lightweight and modular. It has a short learning curve, and allows one to extend its capabilities and express complicated modeling scenarios. Agents.jl is inspired by [Mesa](https://github.com/projectmesa/mesa) framework for Python.

## Other features

### Distributed computing

The `batchrunner_parallel` function allows you to run several simulation replicates in parallel and get all their results in a single Data Frame. It works the same as `batchrunner` except each replicate runs independently.

### Aggregating collected data

Sometimes, it is easier to take summary statistics than collect all the raw data. The `step!` function accepts a list of aggregating functions, e.g. `mean` and `median`. If such a list is provided, each function will apply to a list of the agent fields at each step. Only the summary statistics will be returned. It is possible to pass a dictionary of agent fields and aggregator functions that only apply to those fields. To collect data from the model object, pass `:model` instead of an agent field. To collect data from a list of agent objects, rather than a list of agents' fields, pass `:agent`.

### Running multiple replicates

Since ABMs are stochastic, researchers often run multiple replicates of a simulation and observe its mean behavior. Agents.jl provides the `batchrunner` function which allows running and collecting data from multiple simulation replicates. Furthermore, the `combine_columns!` function merges the results of simulation replicates into single columns using user-passed aggregator functions.

### Exploratory data analysis

Julia has extensive tools for data analysis. Having the results of simulations in `DataFrame` format makes it easy to take advantage of most of such tools. Examples include the VegaLite.jl package for data visualization, which uses a grammar of graphics syntax to produce interactive plots. Moreover, DataVoyager.jl provides an [interactive environment](https://github.com/vega/voyager) to build custom plots from `DataFrame`s. Agents.jl provides `visualize_data` function that sends the simulation outputs to Data Voyager.

## Why we need agent-based modeling

Agent-based models (ABMs) are increasingly recognized as the approach for studying complex systems [[3](https://link.springer.com/chapter/10.1007/3-7908-1721-X_7),[4](http://www.doi.org/10.1162/106454602753694765),[5](http://www.nature.com/articles/460685a),[6](http://www.doi.org/10.1016/j.jaa.2016.01.009)]. Complex systems cannot be fully understood using the traditional mathematical tools that aggregate the behavior of elements in a system. The behavior of a complex system depends on the behavior and interaction of its elements (agents). Small changes in the input to complex systems or the behavior of its agents can lead to large changes in system's outcome. That is to say a complex system's behavior is nonlinear, and that it is not the sum of the behavior of its elements. Use of ABMs have become feasible after the availability of computers and has been growing since, especially in modeling biological and economical systems, and has extended to social studies and archaeology.

An ABM consists of autonomous agents that behave given a set of rules. A classic and simple example of an ABM is a cellular automaton. A cellular automaton is a regular grid where each _cell_ is an agent. Cells have different _states_, for example, on or off. A cell's state can change at each step depending on the state of its _neighbors_. This simple model can lead to unpredictable emergent patterns on the grid. Famous examples of which are Wolfram's rule 22 and rule 30 (see [here](https://link.aps.org/doi/10.1103/RevModPhys.55.601) and figures below).

![Wolfram's rule 22 implemented in Agents.jl](CA1D_22.png)
![Wolfram's rule 30 implemented in Agents.jl](CA1D_30.png)

Another classic example of an ABM is [Schelling's segregation model](https://www.tandfonline.com/doi/abs/10.1080/0022250X.1971.9989794), which we implement in the [Tutorial](@ref) page. This model also uses a regular grid and defines agents as the cells of the grid. Agents can be from different social groups. Agents are happy/unhappy based on the fraction of their neighbors that belong to the same group as they are. If they are unhappy, they keep moving to new locations until they are happy. Schelling's model shows that even small preferences of agents to have neighbors belonging to the same group (e.g. preferring that at least 30% of neighbors to be in the same group) could lead to total segregation of neighborhoods. This is another example of an emergent phenomenon from simple interactions of agents.

## Installation

The package is in Julia's package list. Install it using this command:

```julia
]add Agents
```

## Running tests

Press `]` to go into package manager mode and then
```
test Agents
```


## Alterantive Julia package: DynamicGrids.jl
Agents.jl targets complicated agent based models (ABMs) that are defined on truly arbitrary complex graphs.
Because of this, the core datastructure of this package is a dictionary that maps unique IDs to Agents, as shown in the [Tutorial](@ref) and specifically in [`AgentBasedModel`](@ref).
As all agents are unique entities, if one "dies" it is entirely and forever removed from memory.
Similarly, when a new agent becomes "alive", this literally means that a new agent datastructure is initialized and added to this dictionary.

This design decision allows for arbitrary ABMs and also allows flexible implementation on arbitrary graphs, as well as makes the data collection functionality of Agents.jl powerful and intuitive.
But this is not necessary for *cellular-automata-like* models, where the grid cell and the "agent" identity are fully equivalent.
This is the case e.g. in the [Forest fire](@ref) and [Game of life](@ref) examples.
For such applications the Julia package [DynamicGrids.jl](@ref) can give up to 2 orders of magnitude performance gain than Agents.jl, see [DynamicGrids.jl#10](https://github.com/cesaraustralia/DynamicGrids.jl/issues/10) and [Agents.jl#127](https://github.com/JuliaDynamics/Agents.jl/pull/127), while also allowing advanced visualization.
This happens because in such cases there are numerous optimizations that take advantage of the fact that you don't have to "care" about "agents".

### How to decide?
Use DynamicGrids.jl (or the derivative packages like Dispersal.jl) when your model lives on a rectangular grid, while the value of each grid cell does not have an identity (equivalently, the "identity" of each entity in your model is equivalent with its grid cell). Use Agents.jl when you want to (a) use individual agents whose identity (and other properties) is detached from their location (b) multiple agents can occupy the same location or (c) the spatial model of your structure is an arbitrary graph instead of a rectangular grid.

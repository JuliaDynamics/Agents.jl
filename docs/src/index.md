![Agents.jl](https://github.com/JuliaDynamics/JuliaDynamics/blob/master/videos/agents/agents3_logo.gif?raw=true)

Agents.jl is a pure [Julia](https://julialang.org/) framework for agent-based modeling (ABM).
Agents.jl is part of [JuliaDynamics](https://juliadynamics.github.io/JuliaDynamics/).
To get started, please read the [Tutorial](@ref) page.

!!! tip "Latest news"
    Welcome to Agents.jl v4.0! This new release features improved `GridSpace` and `ContinuousSpace` (re-written from scratch), overall performance improvements of Agents.jl of a full order of magnitude (and sometimes more) and re-naming many API functions to make sense (deprecations have been put in place). Have a look at the [CHANGELOG](https://github.com/JuliaDynamics/Agents.jl/blob/master/CHANGELOG.md) for more details!

## Features

* Intuitive and simple-to-learn software for agent based models.
* Universal model structure where agents are identified by a unique id: [`AgentBasedModel`](@ref)
* Powerful, feature-full and extendable [API](@ref).
* Modular, function-based design.
* Support for many types of space: arbitrary graphs, regular grids, continuous space, or even instances of Open Street Map.
- Multi-agent support, for interactions between disparate agent species.
* Scheduler interface (with default schedulers), making it easy to activate agents in a specific order (e.g. by the value of some property)
* Automatic data collection in a `DataFrame` at desired intervals
* Aggregating collected data during model evolution
* Distributed computing
* Batch running and batch data collection
* Visualize agent distributions on regular grids, arbitrary graphs or continuous space.
* Interactive applications for any agent based model (in continuous or grid space), which are created with only 5 lines of code and look like this:

```@raw html
<video width="auto" controls autoplay loop>
<source src="https://raw.githubusercontent.com/JuliaDynamics/JuliaDynamics/master/videos/interact/agents.mp4?raw=true" type="video/mp4">
</video>
```

## Installation

The package is in Julia's package list. Install it using this command:

```
using Pkg; Pkg.add("Agents")
```

## Design philosophy of Agents.jl
Agents.jl was designed with the following philosophy in mind:

**Simple to learn and use, yet extendable, focusing on fast and scalable model creation and evolution.**

(it should be said nevertheless, that when we have to make a choice between a simpler API or a more performant implementation, we tend to lean in favor of simplicity)

There are multiple examples that highlight this core design principle, that one will quickly encounter when scanning through our [API](@ref) page. Here we just give two quick examples: first, there exists a universal function [`nearby_agents`](@ref), which returns the agents nearby a given agent and within a given "radius". What is special for this function, which is allowed by Julia's Multiple Dispatch, is that `nearby_agents` will work for any space type the model has, reducing the learning curve of finding neighbors in ABMs made with Agents.jl. An even better example is perhaps our treatment of spaces. A user may create an entirely new kind of space (e.g. one representing a planet, or whatever else) by only extending 5 functions, as discussed in our [Creating a new space type](@ref) documentation.

Many other agent-based modeling frameworks have been constructed to ease the process of building and analyzing ABMs (see e.g. [here](http://dx.doi.org/10.1016/j.cosrev.2017.03.001) for an outdated review), spanning a varying degree of complexity.
In the page [ABM Framework Comparison](@ref) we compare how our design philosophy puts us into comparison with other well accepted ABM software.
**Fascinatingly, even though the main focus of Agents.jl is simplicity and ease of use, it outperforms all software we compared it with.**

## Crash course on agent based modeling
An agent-based (or individual-based) model is a computational simulation of autonomous agents that react to their environment (including other agents) given a predefined set of rules [[1](http://doi.org/10.1016/j.ecolmodel.2006.04.023)].
ABMs have been adopted and studied in a variety of research disciplines.
One reason for their popularity is that they enable a relaxation of many simplifying assumptions usually made by mathematical models.
Relaxing such assumptions of a "perfect world" can change a model's behavior [[2](http://doi.org/10.1038/460685a)].

Agent-based models are increasingly recognized as a useful approach for studying complex systems [[3](https://link.springer.com/chapter/10.1007/3-7908-1721-X_7),[4](http://www.doi.org/10.1162/106454602753694765),[5](http://www.nature.com/articles/460685a),[6](http://www.doi.org/10.1016/j.jaa.2016.01.009)].
Complex systems cannot be fully understood using traditional mathematical tools which aggregate the behavior of elements in a system.
The behavior of a complex system depends on both the behavior of and interactions between its elements (agents).
Small changes in the input to complex systems or the behavior of its agents can lead to large changes in outcome.
That is to say, a complex system's behavior is nonlinear, and that it is not only the sum of the behavior of its elements.
Use of ABMs have become feasible after the availability of computers and has been growing ever since, especially in modeling biological and economical systems, and has extended to social studies and archaeology.

An ABM consists of autonomous agents that behave given a set of rules.
A classic example of an ABM is [Schelling's segregation model](https://www.tandfonline.com/doi/abs/10.1080/0022250X.1971.9989794), which we implement as an example here.
This model uses a regular grid and defines agents at random positions on the grid.
Agents can be from different social groups.
Agents are happy/unhappy based on the fraction of their neighbors that belong to the same group as they are.
If they are unhappy, they keep moving to new locations until they are happy.
Schelling's model shows that even small preferences of agents to have neighbors belonging to the same group (e.g. preferring that at least 30% of neighbors to be in the same group) could lead to total segregation of neighborhoods.
This is an example of emergent behavior from simple interactions of agents that can only be captured in an agent-based model.

## Citation

If you use this package in work that leads to a publication, then please cite the paper below:

```
@misc{Agents.jl,
      title={Agents.jl: A performant and feature-full agent based modelling software of minimal code complexity},
      author={George Datseris and Ali R. Vahdati and Timothy C. DuBois},
      year={2021},
      eprint={2101.10072},
      archivePrefix={arXiv},
      primaryClass={cs.MA}
}
```

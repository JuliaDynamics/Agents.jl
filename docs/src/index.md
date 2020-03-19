# Agents.jl Documentation

![Agents.jl](https://github.com/JuliaDynamics/JuliaDynamics/blob/master/videos/agents/agents_logo.gif?raw=true)

Agents.jl is a [Julia](https://julialang.org/) framework for agent-based modeling (ABM).
Agents.jl is part of [JuliaDynamics](https://juliadynamics.github.io/JuliaDynamics/).
To get started, please read the [Tutorial](@ref) page.

!!! info "Latest news"
    You are currently reading the _development_ version of the documentation, which is being prepared for Agents.jl 3.0. In this major release we have full support for agent based models on [`ContinuousSpace`](@ref), but have not yet finished development. See the [CHANGELOG](https://github.com/JuliaDynamics/Agents.jl/blob/master/CHANGELOG.md) for a full list of changes.

## Features

* Intuitive, small yet powerful, and simple to learn API for agent based models.
* Universal model structure where agents are identified by a unique id: [`AgentBasedModel`](@ref)
* Support for all possible types of spaces: arbitrary graphs, regular grids, or continuous space.
* Scheduler interface (with default schedulers), making it easy to activate agents in a specific order (e.g. by the value of some property)
* Automatic data collection in a `DataFrame` at desired intervals
* Aggregating collected data during model evolution
* Distributed computing
* Batch running and batch data collection
* Visualize agent distributions on regular grids, arbitrary graphs or continuous space.

## Installation

The package is in Julia's package list. Install it using this command:

```
]add Agents
```

## Comparison with existing software

Many agent-based modeling frameworks have been constructed to ease the process of building and analyzing ABMs (see [here](http://dx.doi.org/10.1016/j.cosrev.2017.03.001) for a review). Notable examples are [NetLogo](https://ccl.northwestern.edu/netlogo/), [Repast](https://repast.github.io/index.html), [MASON](https://journals.sagepub.com/doi/10.1177/0037549705058073), and [Mesa](https://github.com/projectmesa/mesa).

Implementing an ABM framework in Julia has several advantages:
1. Using a general purpose programming language instead of a custom scripting language, such as NetLogo's, removes a learning step and provides a single environment for building the models and analyzing their results.
2. Julia has a rich ecosystem for data analysis and visualization, implemented and maintained independently from Agents.jl.
3. Julia is easier-to-use than Java (used for Repast and MASON), and provides a REPL (Read-Eval-Print-Loop) environment to build and analyze models interactively.
4. Unlike Python (used for Mesa), Julia is fast to run. This is a crucial criterion for models that require considerable computations.
5. Because the direct output of Agents.jl is a `DataFrame`, it makes it easy to use tools as DataVoyager.jl, which provide an [interactive environment](https://github.com/vega/voyager) to build custom plots from `DataFrame`s. (and of course the `DataFrame` itself is a tabular data format similar to Python's Pandas).

Agents.jl is lightweight and modular. It has a short learning curve, and allows one to extend its capabilities and express complicated modeling scenarios. Agents.jl was originally inspired by the [Mesa](https://github.com/projectmesa/mesa) framework for Python, but has since then seen several improvements over the original (e.g. simpler API, shorter learning curve, continuous space and more than 10 times better performance).


## Crash course on agent based modeling
An agent-based (or individual-based) model is a computational simulation of autonomous agents that react to their environment (including other agents) given a predefined set of rules [[1](http://doi.org/10.1016/j.ecolmodel.2006.04.023)]. ABM has gained wide usage in a variety of research disciplines. One reason for its popularity is that it allows relaxing many simplifying assumptions usually made by mathematical models. Relaxing such assumptions of a "perfect world" can change a model's behavior [[2](http://doi.org/10.1038/460685a)]. ABM is specifically an important tool for studying complex systems where a system's behavior cannot be predicted and has to be explored (see the "Why we need ABM" section for detailed examples).

Agent-based models are increasingly recognized as the approach for studying complex systems [[3](https://link.springer.com/chapter/10.1007/3-7908-1721-X_7),[4](http://www.doi.org/10.1162/106454602753694765),[5](http://www.nature.com/articles/460685a),[6](http://www.doi.org/10.1016/j.jaa.2016.01.009)]. Complex systems cannot be fully understood using the traditional mathematical tools that aggregate the behavior of elements in a system. The behavior of a complex system depends on the behavior and interaction of its elements (agents). Small changes in the input to complex systems or the behavior of its agents can lead to large changes in system's outcome. That is to say a complex system's behavior is nonlinear, and that it is not the sum of the behavior of its elements. Use of ABMs have become feasible after the availability of computers and has been growing since, especially in modeling biological and economical systems, and has extended to social studies and archaeology.

An ABM consists of autonomous agents that behave given a set of rules. A classic example of an ABM is [Schelling's segregation model](https://www.tandfonline.com/doi/abs/10.1080/0022250X.1971.9989794), which we implement as an example here. This model also uses a regular grid and defines agents as the cells of the grid. Agents can be from different social groups. Agents are happy/unhappy based on the fraction of their neighbors that belong to the same group as they are. If they are unhappy, they keep moving to new locations until they are happy. Schelling's model shows that even small preferences of agents to have neighbors belonging to the same group (e.g. preferring that at least 30% of neighbors to be in the same group) could lead to total segregation of neighborhoods. This is another example of an emergent phenomenon from simple interactions of agents.

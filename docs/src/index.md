```@docs
Agents
```

```@setup MAIN
using CairoMakie, Agents
```

!!! info "Star us on GitHub!"
    If you have found this package useful, please consider starring it on [GitHub](https://github.com/JuliaDynamics/Agents.jl).
    This gives us an accurate lower bound of the (satisfied) user count.

!!! tip "Latest news: Agents.jl v6.0"
    This is a new major release of Agents.jl with great new content
    and massive performance increases all across the board!
    Please see the online [CHANGELOG](https://github.com/JuliaDynamics/Agents.jl/blob/main/CHANGELOG.md) for a full list of changes.
    The most noteworthy ones are:

    - A new macro `@multiagent` allows to run multi-agent simulations more efficiently.
    - A new experimental model type `EventQueueABM` has been implemented. It operates in continuous time through the scheduling of events at arbitrary time points. It is a generalization of "Gillespie-like" models.
    - `AgentBasedModel` defines an API that can be extended by other models.
    - Stronger inheritance capabilities in `@agent`.
    - Manually setting or altering the ids of agents is no longer allowed. The agent id is now considered a read-only field, and is set internally by Agents.jl.


## Highlights

### Software quality

* Free and open source.
* Small learning curve due to intuitive design based on a modular space-agnostic function-based modelling implementation.
* Extremely high performance when compared to other open source frameworks, routinely being 100x faster versus other ABM frameworks ([proof](https://github.com/JuliaDynamics/ABM_Framework_Comparisons))
* User-created models typically have much smaller source code versus implementations in other open source ABM frameworks ([proof](https://github.com/JuliaDynamics/ABM_Framework_Comparisons))
* High quality, extensive documentation featuring tutorials, example ABM implementations, an [extra zoo of ABM examples](https://juliadynamics.github.io/AgentsExampleZoo.jl/dev/), and integration examples with other Julia packages


```@raw html
<video width="auto" controls autoplay loop>
<source src="https://raw.githubusercontent.com/JuliaDynamics/JuliaDynamics/master/videos/agents/showcase.mp4?raw=true" type="video/mp4">
</video>
```


### Agent based modelling

* Universal model structure where agents are identified by a unique id: [`AgentBasedModel`](@ref).
* Extendable [API](@ref) that provides out of the box thousands of possible agent actions.
* Support for many types of space: arbitrary graphs, regular grids, continuous space
* Support for simulations on Open Street Maps including support for utilizing the road's max speed limit, finding nearby agents/roads/destinations and pathfinding
* Multi-agent support, for interactions between disparate agent species
* Scheduler interface (with default schedulers), making it easy to activate agents in a specific order (e.g. by the value of some property)
* Automatic data collection in a `DataFrame` at desired intervals
* Aggregating collected data during model evolution
* Distributed computing
* Batch running and batch data collection
* Extensive pathfinding capabilities in continuous or discrete spaces
* Customizable visualization support for all kinds of models via the [Makie](https://makie.juliaplots.org/stable/) ecosystem: publication-quality graphics and video output
* Interactive applications for any agent based models, which are created with only 5 lines of code and look like this:

```@raw html
<video width="auto" controls autoplay loop>
<source src="https://raw.githubusercontent.com/JuliaDynamics/JuliaDynamics/master/videos/interact/agents.mp4?raw=true" type="video/mp4">
</video>
```

## Getting started

To install Agents.jl, launch Julia and then run this command:

```
using Pkg; Pkg.add("Agents")
```

To learn how to use Agents.jl, please visit the [Tutorial](@ref) before anything else.

!!! tip "Use the latest released version"
    After adding Agents.jl to your project, please check if the most up to date
    [stable version](https://github.com/JuliaDynamics/Agents.jl/releases/latest)
    has been installed.
    The versions of the installed packages in the project can be checked by
    running `Pkg.status()`.
    Only the latest version of Agents.jl provides all the features described
    in this documentation.
    It is generally advised against using earlier versions as they will likely
    only work partially and are not supported anymore.

## Design philosophy of Agents.jl

Agents.jl was designed with the following philosophy in mind:

**Simple to learn and use, yet extendable and highly performant, allowing for fast and scalable model creation and evolution.**



There are multiple examples that highlight this core design principle, that one will quickly encounter when scanning through our [API](@ref) page. Here we just give two quick examples: first, there exists a universal function [`nearby_agents`](@ref), which returns the agents nearby a given agent and within a given "radius". What is special for this function, which is allowed by Julia's Multiple Dispatch, is that `nearby_agents` will work for any space type the model has, reducing the learning curve of finding neighbors in ABMs made with Agents.jl. An even better example is perhaps our treatment of spaces. A user may create an entirely new kind of space (e.g. one representing a planet, or whatever else) by only extending 5 functions, as discussed in our [Creating a new space type](@ref) documentation. Indeed, the simplicity of Agents.jl is due to the intuitive space-agnostic modelling approach we have implemented: agent actions are specified using generically named functions (such as "move agent" or "find nearby agents") that do not depend on the actual space the agents exist in, nor on the properties of the agents themselves. Overall this leads to ultra fast model prototyping where even changing the space the agents live in is matter of only a couple of lines of code.

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
Use of ABMs have become feasible after the availability of computers and has been growing ever since, especially in modeling biological and economic systems, and has extended to social studies and archaeology.

An ABM consists of autonomous agents that behave given a set of rules.
A classic example of an ABM is [Schelling's segregation model](https://www.tandfonline.com/doi/abs/10.1080/0022250X.1971.9989794), which we implement as an example here.
This model uses a regular grid and defines agents at random positions on the grid.
Agents can be from different social groups.
Agents are happy/unhappy based on the fraction of their neighbors that belong to the same group as they are.
If they are unhappy, they keep moving to new locations until they are happy.
Schelling's model shows that even small preferences of agents to have neighbors belonging to the same group (e.g. preferring that at least 30% of neighbors to be in the same group) could lead to total segregation of neighborhoods.
This is an example of emergent behavior from simple interactions of agents that can only be captured in an agent-based model.

## Getting help

You're looking for support for Agents.jl? Look no further! Here are some things you can do to resolve your questions about Agents.jl:

1. Read the online documentation! It is likely that the thing you want to know is already documented, so use the search bar and search away!
2. Chat with us in the channel `#dynamics-bridged` in the [Julia Slack](https://julialang.org/slack/)!
3. Post a question in the [Julia discourse](https://discourse.julialang.org/) in the category “Modelling and simulations”, using `agents` as a tag!
4. If you believe that you have encountered unexpected behavior or a bug in Agents.jl, then please do open an issue on our [GitHub page](https://github.com/JuliaDynamics/Agents.jl) providing a minimal working example!

## Contributing

Any contribution to Agents.jl is welcome! For example you can:

* Add new feature or improve an existing one (plenty to choose from the "Issues" page)
* Improve the existing documentation
* Add new example ABMs into our existing pool of examples
* Report bugs and suggestions in the Issues page

Have a look at [contributor's guide](https://github.com/SciML/ColPrac) of the SciML organization for some good information on contributing to Julia packages!

## Citation

If you use this package in work that leads to a publication, then please cite the paper below:

```
@article{Agents.jl,
  doi = {10.1177/00375497211068820},
  url = {https://doi.org/10.1177/00375497211068820},
  year = {2022},
  month = jan,
  publisher = {{SAGE} Publications},
  pages = {003754972110688},
  author = {George Datseris and Ali R. Vahdati and Timothy C. DuBois},
  title = {Agents.jl: a performant and feature-full agent-based modeling software of minimal code complexity},
  journal = {{SIMULATION}},
  volume = {0},
  number = {0},
}
```

## Reproducibility

```@raw html
<details><summary>The documentation of Agents.jl was built using these direct dependencies,</summary>
```

```@example
using Pkg # hide
Pkg.status() # hide
```

```@raw html
</details>
```

```@raw html
<details><summary>and using this machine and Julia version.</summary>
```

```@example
using InteractiveUtils # hide
versioninfo() # hide
```

```@raw html
</details>
```

```@raw html
<details><summary>A more complete overview of all dependencies and their versions is also provided.</summary>
```

```@example
using Pkg # hide
Pkg.status(; mode = PKGMODE_MANIFEST) # hide
```

```@raw html
</details>
```

```@eval
using TOML
using Markdown
version = TOML.parse(read("../../Project.toml", String))["version"]
name = TOML.parse(read("../../Project.toml", String))["name"]
link_manifest = "https://github.com/Agents/" * name * ".jl/tree/gh-pages/v" * version *
                "/assets/Manifest.toml"
link_project = "https://github.com/Agents/" * name * ".jl/tree/gh-pages/v" * version *
               "/assets/Project.toml"
Markdown.parse("""You can also download the
[manifest]($link_manifest)
file and the
[project]($link_project)
file.
""")
```


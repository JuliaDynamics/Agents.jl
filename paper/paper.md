---
title: 'Agents.jl: agent-based modeling framework in Julia'
tags:
  - Julia
  - ABM
  - agent-based model
authors:
  - name: Ali R. Vahdati
    orcid: 0000-0003-0895-1495
    affiliation: 1 # (Multiple affiliations must be quoted)
affiliations:
 - name: Department of Anthropology, University of Zurich, Zurich, Switzerland
   index: 1
date: 25 June 2019
bibliography: paper.bib
---

# Summary

Agent-based modeling involves designing a system of autonomous agents that interact based on a set of given rules [@grimm2006standard]. It is used for studying complex systems whose behavior cannot be easily identified using classical mathematical approaches.

ABM provides a bottom-up approach for studying complex systems, whereas analytical models have a top-down one [@Bonabeau2002]. The two approaches are complementary and they both can benefit from insights that the other approach contributes. Analytical models make many simplifying assumptions about the systems they study. This results in systems that are tractable and lead to clear conclusions. Agent-based models on the other hand, are more difficult to make sense of because they relax many assumptions of equation-based approaches. This is at the same time an advantage of agent-based models because it allows observing the effect of agent and environment heterogeneity and stochasticity, which can change a model's behavior [@Farmer2009]. ABM is specifically an important tool for studying complex systems where a system's behavior cannot be predicted and has to be explored.

There are currently several agent-based modeling frameworks available (notable examples are NetLogo [@Wilensky1999], Repast [@North2013], MASON [@Luke2005], and Mesa [@Masad2015]), but not for the Julia language, a new language designed with the needs of scientific computing in mind, such as interactivity, speed, and expressiveness. Julia language provides a combination of features that were historically mutually exclusive. Specifically, languages that were fast to write, such as Python, were slow to run. And languages that were fast to run, such as C/C++, were slow to write. The combination of these two features, and the expressive structure of the language, makes Julia a desirable choice for scientific purposes. Agent-based models can involve hundreds of thousands of agents, each of which performing certain computations at each time-step. Thus, having a modeling framework that makes writing models easier and results in fast code is an advantage. I introduce the first of such frameworks in Julia: Agents.jl. An ABM framework in Julia provides advantages to the existing frameworks in other languages. First, unlike NetLogo, Agents.jl uses a general-purpose language rather than custom one, which reduces the learning curve and unifies the modeling and analysis language. Second, Julia is an easy to learn and easy to write language, unlike Java that is used for Repast and MASON, and provides a REPL (Read-Eval-Print-Loop) to build and analyze models interactively. Third, Julia is fast to run unlike Python used for Mesa (see Fig. 1). This can be important in large agent-based models.

![Speed comparison of a version of "forest fire" model in Agents.jl vs Mesa. The same implementation of the model in Agents.jl (originally taken from Mesa's example and then re-implemented in Agents.jl) shows more than 8x speed gain. See the docs for more details.](benchmark01.png)

Agent.jl framework allows users to only think about what needs to happen during each step of their model, and the rest will be managed by the framework. In its current version, it does not provide tools to visualize simulations in real time. Moreover, a GUI can make the package even more accessible. The examples in the documentation show the workflow and features of the package.

## Features

* Built-in 2D and 3D regular grids with Moore and von Neumann neighborhoods and periodic edges
* Automatic data collection into a "DataFrame"
* Automatic aggregation of collected data with user defined functions.
* Sometimes, it is easier to take summary statistics than collect all the raw data. The `step!` function accepts a list of aggregating functions, e.g. `mean` and `median`.
* Data visualization with "DataVoyager": it allows users to interactively plot and explore simulation outputs.
* Running and aggregation of simulation replicates: Agents.jl provides functions to run multiple simulation replicates and collect their data into a "DataFrame". Furthermore, it allows merging the the results of each replicate into single columns using user-defined aggregator functions.
* Automatic plotting of Cellular Automata.
* Automatic distributed computing: Agents.jl allows simulation replicates to run in parallel. It then collects the data from all replicates into a single "Data Frame".

# References
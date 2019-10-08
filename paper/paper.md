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

Agent-based modeling provides a bottom-up approach for studying complex systems, whereas analytical models have a top-down one [@Bonabeau2002]. The two approaches are complementary and they both can benefit from insights that the other approach contributes. Analytical models make many simplifying assumptions about the systems they study. This results in systems that are tractable and lead to clear conclusions. Agent-based models, on the other hand, are more difficult to make sense of because they relax many assumptions of equation-based approaches. This is at the same time an advantage of agent-based models because it allows observing the effect of agent and environment heterogeneity and stochasticity, which can change a model's behavior [@Farmer2009]. Agent-based modeling is a particularly important tool for studying complex systems where a system's behavior cannot be predicted and has to be explored.

There are currently several agent-based modeling frameworks available (notable examples are NetLogo [@Wilensky1999], Repast [@North2013], MASON [@Luke2005], and Mesa [@Masad2015]), but not for the Julia language, a new language designed with the needs of scientific computing in mind. Julia provides a combination of features that have historically been mutually exclusive. Specifically, languages that were fast to write, such as Python, were slow to run. And languages that were fast to run, such as C/C++, were slow to write. The combination of speed, expressiveness, and support for interactive computing makes Julia a desirable choice for scientific purposes. Agent-based models can involve hundreds of thousands of agents, each performing certain computations at each time step, thus speed is essential.  Agents.jl is the first high-performance agent-based modeling framework to be written in Julia, and offers key advantages relative to the existing frameworks in other languages. First, unlike NetLogo, Agents.jl uses a general-purpose language rather than custom one, which reduces the learning curve and unifies the modeling and analysis language. Second, Julia is an easy to learn and easy to write language, unlike Java that is used for Repast and MASON, and provides a REPL (Read-Eval-Print-Loop) to build and analyze models interactively. Third, Julia is fast to run, unlike Python, which is used for Mesa (see Figure 1). This can be important in large agent-based models.

![Speed comparison of a version of the "forest fire" model in Agents.jl vs Mesa. The same implementation of the model in Agents.jl (originally taken from Mesa's example and then re-implemented in Agents.jl) shows more than 8x speed gain. See the documentation for more details. The comparison was performed on a Windows machine with a i7-6500U CPU and 16 GB of RAM. ](benchmark01.png)

Agents.jl allows users to only think about what needs to happen during each step of their model, and the rest will be managed by the framework. Future development can include building a GUI to help users with less programming knowledge, and implementing real-time visualization of simulations. The [documentation](https://kavir1698.github.io/Agents.jl/dev/) contains a tutorial and several example agent-based models to demonstrate the features and workflows supported by the package.

## Features

* Built-in 2D and 3D regular grids with Moore and von Neumann neighborhoods and periodic edges.
* Automatic data collection into a "DataFrame".
* Automatic aggregation of collected data with user defined functions.
* Automatic aggregation of raw outputs with user-defined summary statistics. 
* Interactive visualization of simulation outputs with "DataVoyager".
* Running and aggregating simulation replicates.
* Visualizing cellular automata.
* Parallel computation of simulation replicates.

# References

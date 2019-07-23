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

Agent-based modeling involves designing a system of autonomous agents that interact based on a set of given rules. It is used for studying complex systems whose behavior cannot be easily identified using classical mathematical approaches. There are currently several agent-based modeling frameworks available (notable examples are NetLogo [@Wilensky1999], Repast [@North2013], MASON [@Luke2005], and Mesa [@Masad2015]), but not for the Julia language, a new language designed with the needs of scientific computing in mind, such as interactivity, speed, and expressiveness. I introduce the first of such frameworks in Julia: Agents.jl. An ABM framework in Julia provides advantages to the existing frameworks in other languages. First, unlike NetLogo, Agents.jl uses a general-purpose language rather than custom one, which reduces the learning curve and unifies the modeling and analysis language. Second, Julia is an easy to learn and easy to write language, unlike Java that is used for Repast and MASON, and provides a REPL (Read-Eval-Print-Loop) to build and analyze models interactively. Third, Julia is fast to run unlike Python used for Mesa (see Fig. 1). This is can be important in large agent-based models.

![Speed comparison of a version of "forest fire" model in Agents.jl vs Mesa. The same implementation of the model in Agents.jl (originally taken from Mesa's example and then re-implemented in Agents.jl) shows more than 8x speed gain. See the docs for more details.](benchmark01.png)

Agent.jl framework allows users to only think about what needs to happen during each step of their model, and the rest will be managed by the framework. The examples in the documentation show the workflow and features of the package.

## Features

* Built-in 2D and 3D regular grids with Moore and von Neumann neighborhoods and periodic edges
* Automatic data collection into a "DataFrame"
* Automatic aggregation of collected data with user defined functions. Sometimes, it is easier to take summary statistics than collect all the raw data. The `step!` function accepts a list of aggregating functions, e.g. `mean` and `median`.
* Data visualization with "DataVoyager": it allows users to interactively plot and explore simulation outputs.
* Running and aggregation of simulation replicates: Agents.jl provides functions to run multiple simulation replicates and collect their data into a "DataFrame". Furthermore, it allows merging the the results of each replicate into single columns using user-defined aggregator functions.
* Automatic plotting of Cellular Automata.
* Automatic distributed computing: Agents.jl allows simulation replicates to run in parallel. It then collects the data from all replicates into a single "Data Frame".

# References
![Agents.jl](https://github.com/JuliaDynamics/JuliaDynamics/blob/master/videos/agents/agents4_logo.gif?raw=true)

[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://JuliaDynamics.github.io/Agents.jl/stable)
[![](https://img.shields.io/badge/DOI-10.1177/00375497211068820-purple)](https://journals.sagepub.com/doi/10.1177/00375497211068820)
[![CI](https://github.com/JuliaDynamics/Agents.jl/workflows/CI/badge.svg)](https://github.com/JuliaDynamics/Agents.jl/actions?query=workflow%3ACI)
[![codecov](https://codecov.io/gh/JuliaDynamics/Agents.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/JuliaDynamics/Agents.jl)
[![Package Downloads](https://shields.io/endpoint?url=https://pkgs.genieframework.com/api/v1/badge/Agents)](https://pkgs.genieframework.com?packages=Agents)

Agents.jl is a pure [Julia](https://julialang.org/) framework for agent-based modeling (ABM). Agents.jl is [objectively the fastest open source ABM framework](https://github.com/JuliaDynamics/ABM_Framework_Comparisons) out there, routinely being 100x faster than competing open software (MASON, NetLogo, Mesa). Agents.jl is also the only open source ABM framework that fully implements simulations on Open Street Maps.

Besides its incredible performance, two more major highlights of Agents.jl are its simplicity and the total amount of features. Agents.jl is designed to require writing minimal code and being very simple to learn and use, even though it provides an extensive API with thousands of possibilities for agent actions. This simplicity is due to the intuitive space-agnostic modelling approach we have implemented: agent actions are specified using generically named functions that do not depend on the actual space the agents exist in or on the properties of the agents themselves. Overall this leads to ultra fast model prototyping where even changing the space of the agents is matter of only a couple of lines of code.

More information and an extensive list of features can be found in the documentation, which you can either find [online](https://juliadynamics.github.io/Agents.jl/stable/) or build locally by running the `docs/make.jl` file.

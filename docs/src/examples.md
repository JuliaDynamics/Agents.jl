# Overview of Examples

Our ever growing list of examples are designed to showcase what is possible with
Agents.jl. Here, we outline a number of topics that new and advanced users alike can
quickly reference to find exactly what they're looking for.

## I've never used an ABM before where should I start?

The simplest, and most thoroughly discussed example we have is
[Schelling's segregation model](@ref). Here, you will learn how to create an agent,
define its actions, collect data from an experiment, plot results and even how to set
up multiple experiments in parallel.

[Opinion spread](@ref) is another all-round showcase of these topics, with some
interesting, yet more complicated dynamics.

## Concepts

There are many things to learn in the ABM space. Here are some of the more common ones
Agents.jl covers.

### Spaces

Choosing what kind of space your agents occupy is a fundamental aspect of model creation.
Agents.jl provides a number of solutions, and the ability to
[create your own](https://github.com/JuliaDynamics/Agents.jl/blob/master/src/core/space_interaction_API.jl).

Maybe you don't need a space? The [Wright-Fisher model of evolution](@ref) is a good
example to take a look at first to see if you can solve your problem without one.

Making a discrete grid is perhaps the easiest way to conceptualise space in a model.
[Sugarscape](@ref) is one of our more complex examples, but gives you a good overview
of what is possible on a grid. If you're looking for something simpler, then the
[Forest fire model](@ref) would be a good start.

A more complex, but far more powerful space type is something we call
[`ContinuousSpace`](@ref). In this space, agents generally move with a given velocity
and interact in a far smoother manner than grid based models. The [Flock model](@ref)
is perhaps the most famous example of bottom-up emergent phenomena. Something quite
topical at present is our
[Continuous space social distancing for COVID-19](@ref) example.
Finally, an excellent example of what can be done in a continuous space:
[Bacterial Growth](@ref).

Perhaps geographical space is not so important for your model, but connections between
agents in some other manner is. A [`GraphSpace`](@ref) may be the answer.
[SIR model for the spread of COVID-19](@ref) showcases how viral spread may occur in
populations.

Using graphs in conjunction with grid spaces is also possible, we discuss this in one
of our integration pages: [Social networks with LightGraphs.jl](@ref).

Finally, [Battle Royale](@ref) is an advanced example which leverages a 3-dimensional
grid space, but only uses 2 of those dimensions for space. The third represents an
agent **category**. Here, we can leverage Agents.jl's sophisticated neighbor searches
to find closely related agents not just in space, but also in property.

### Agent Path-finding

On [`GridSpace`](@ref)'s, the [`AStar`](@ref) algorithm provides automatic path-finding
for agents with a variety of options and metrics to choose from. We have two models
showcasing the possibilities of this method: [Maze Solver](@ref) and [Runners](@ref).

### Synchronous agent updates

Most of the time, using the `agent_step!` loop then the `model_step!` is
sufficient to evolve a model. What if there's a more complicated set of dynamics you need
to employ? Take a look at the [HK (Hegselmann and Krause) opinion dynamics model](@ref):
it shows us how to make a second agent loop within `model_step!` to synchronise changes
across all agents after `agent_step!` dynamics have completed.

### Agent sampling

The [Wright-Fisher model of evolution](@ref) shows us how we can sample a population of
agents based on certain model properties. This is quite helpful in genetic and biology
studies where agents are cell analogues.

### Cellular Automata

A subset of ABMs, these models have individual agents with a set of behaviors,
interacting with neighboring cells and the world around them, but never moving.
Two famous examples of this model type are [Conway's game of life](@ref) and
[Daisyworld](@ref).

### Mixed Models

In the real world, groups of people interact differently with people they know vs people
they don't know. In ABM worlds, that's no different.
[Model of predator-prey dynamics](@ref) (or more colloquially: Wolf-Sheep) implements
interactions between a pack of Wolves, a heard of Sheep and meadows of Grass.
[Daisyworld](@ref) is an example of how a model property (in this case temperature) can
be elevated to an agent type.

## Advanced Topics

One major difference between Agents.jl and other ABM frameworks is how integrated it is
to the greater ecosystem of the Julia language and by extension the tools one can apply
in their models. Take a look at some of the more advanced walkthroughs in the *Ecosystem Integration*
page of this documentation for details.

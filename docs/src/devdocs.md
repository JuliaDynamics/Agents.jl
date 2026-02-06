# Developer Docs

## Internal infrastructure overview

When it comes to development of new code, the overwhelming majority of
Agents.jl is composed of three parts:

1. The model time-stepping dynamics and agent storage and retrieval logic
2. The space agent storage, movement, and neighborhood searching logic
3. The rest of the API which is largely agnostic to the above two

Arguably the most important aspect of the Agents.jl design is that the above
three pillars of the infrastructure are **orthogonal**. That is, if someone
wanted to add a new space, they would **not** have to care about neither
the model stepping dynamics, nor the majority of the remaining Agents.jl
API, such as sampling, data collection, etc. etc.

## Cloning the repository

Since we include documentation with many animated gifs and videos in the repository, a standard clone can be larger than expected.
If you wish to do any development work, it is better to use

```bash
git clone https://github.com/JuliaDynamics/Agents.jl.git --single-branch
```

## [Creating a new model type](@id make_new_model)

Note that new model types target applications where a fundamentally different
way to define the "time evolution" or "dynamic rule" is required.
If any of the existing [`AgentBasedModel`](@ref) subtypes satisfy the type
of time stepping, then you don't have to create a new type of model.

Creating a new model type within Agents.jl is simple.
Although it requires extending a bit more than a dozen functions, the majority
of them are 1-liner "accessor" functions
(that return e.g., the rng, or the space instance).

The most important mandatory method is to extend `step!` for your new type.
You can see the existing implementations of `step!` for e.g.,
[`StandardABM`](@ref) or [`EventQueueABM`](@ref) to get an idea.

All other mandatory method extensions for e.g., accessor functions are in the file
[`src/core/model_abstract.jl`](https://github.com/JuliaDynamics/Agents.jl/blob/main/src/core/model_abstract.jl).
As you will notice, the overwhelming majority of required methods have a
default implementation that e.g., attempts to return a field named `:rng`.
The rest of the methods by default return a "not implemented" error message
(and those you also need to extend mandatorily).

## [Creating a new space type](@id make_new_space)

Creating a new space type within Agents.jl is quite simple and requires the extension of only 5 methods to support the entire Agents.jl API.
Here are the steps to follow to create a new space:

1. Think about what the agent position type should be.
2. Think about how the space type will keep track of the agent positions, so that it is possible to implement the function [`nearby_ids`](@ref).
3. Implement the `struct` that represents your new space, while making it a subtype of `Agents.AbstractSpace`.
4. Extend `random_position(model::ABM{YourSpaceType})`.
5. Extend `add_agent_to_space!(agent, model), remove_agent_from_space!(agent, model)`. This already provides access to `add_agent!, kill_agent!` and `move_agent!`.
6. Extend `nearby_ids(pos, model, r)`.
7. Create a new "minimal" agent type to be used with [`@agent`](@ref) (see the source code of [`GraphAgent`](@ref) for an example).

And that's it! Every function of the main API will now work. In some situations you might want to explicitly extend other functions such as `move_agent!` or `remove_all_from_space!` for performance reasons, but they will work out of the box with a generic implementation.

### Visualization of a custom space

Visualization of a new space type within Agents.jl works in a similar fashion to
creating a new space type.
One your space works with the general Agents.jl API, you only need to extend a few functions for it to work automatically with the existing plotting and animation infrastructure.

#### Mandatory methods

You must extend the following function

```@docs
space_axis_limits
```

#### Optional alternative agent plotting

If your space does not visualize agents in the default way of one agent = one scattered marker, then you want to extend some or all of the following functions.
For example, `GraphSpace` aggregates multiple agents into one scattered marker and is extending these functions.

```@docs
agentsplot!
abmplot_pos
abmplot_colors
abmplot_markers
abmplot_markersizes
```

#### Optional pre-plotting

Some spaces, like the `OSMSpace`, need to plot some elements before the agents can be plotted and animated. If that's the case, extend the following:

```@docs
spaceplot!
```

#### Heatmap handling

Heatmaps are extracted and plotted automatically, but your space may require some special handling for that. For example `ContinuousSpace` needs to map the finite heatmap matrix over the continuous space.
If you require such handling, extend:

```@docs
abmheatmap!
```

## Designing a new Pathfinder Cost Metric

To define a new cost metric, simply make a struct that subtypes `CostMetric` and provide
a `delta_cost` function for it. These methods work solely for A* at present, but
will be available for other pathfinder algorithms in the future.

```@docs
Pathfinding.CostMetric
Pathfinding.delta_cost
```

## Implementing custom serialization

### For model properties

Custom serialization may be required if your properties contain non-serializable data, such as
functions. Alternatively, if it is possible to recalculate some properties during deserialization
it may be space-efficient to not save them. To implement custom serialization, define methods
for the `to_serializable` and `from_serializable` functions:

```@docs
AgentsIO.to_serializable
AgentsIO.from_serializable
```

### For agent structs

Similarly to model properties, you may need to implement custom serialization for agent structs.
`from_serializable` and `to_serializable` are not called during (de)serialization of agent structs.
Instead, [JLD2's custom serialization functionality](https://juliaio.github.io/JLD2.jl/stable/customserialization/)
should be used. All instances of the agent struct will be converted to and from the specified
type during serialization. For OpenStreetMap agents, the position, destination and route are
saved separately. These values will be loaded back in during deserialization of the model and
override any values in the agent structs. To save space, the agents in the serialized model
will have empty `route` fields.

## OpenStreetMapSpace internals

Details about the internal details of the OSMSpace are discussed in the docstring of `OSM.OpenStreetMapPath`.

## Benchmarking

As Agents.jl is developed we want to monitor code efficiency through
_benchmarks_. A benchmark is a function or other bit of code whose execution is
timed so that developers and users can keep track of how long different API
functions take when used in various ways. Individual benchmarks can be organized
into _suites_ of benchmark tests. See the
[`benchmark`](https://github.com/JuliaDynamics/Agents.jl/tree/main/benchmark)
directory to view Agents.jl's benchmark suites. Follow these examples to add
your own benchmarks for your Agents.jl contributions. See the BenchmarkTools
[quickstart guide](https://github.com/JuliaCI/BenchmarkTools.jl#quick-start),
[toy example benchmark
suite](https://github.com/JuliaCI/BenchmarkTools.jl/blob/master/benchmark/benchmarks.jl),
and the [BenchmarkTools.jl
manual](https://juliaci.github.io/BenchmarkTools.jl/dev/manual/#Benchmarking-basics)
for more information on how to write your own benchmarks.

## Creating a new `AgentBasedModel` implementation

The interface defined by `AgentBasedModel`, that needs to be satisfied by new implementations, is very small. It is contained in the file `src/core/model_abstract.jl`.

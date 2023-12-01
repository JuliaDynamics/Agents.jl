# Developer Docs

## Cloning the repository

Since we include documentation with many animated gifs and videos in the repository, a standard clone can be larger than expected.
If you wish to do any development work, it is better to use

```bash
git clone https://github.com/JuliaDynamics/Agents.jl.git --single-branch
```

## Custom space type

### Creating a new space type
Creating a new space type within Agents.jl is quite simple and requires the extension of only 5 methods to support the entire Agents.jl API. 
The exact specifications on how to create a new space type are contained within the source file: [`src/core/space_interaction_API.jl`](https://github.com/JuliaDynamics/Agents.jl/blob/main/src/core/space_interaction_API.jl).

In principle, the following should be done:

1. Think about what the agent position type should be. Add this type to the `ValidPos` union type in `src/core/model_abstract.jl`.
1. Think about how the space type will keep track of the agent positions, so that it is possible to implement the function [`nearby_ids`](@ref).
1. Implement the `struct` that represents your new space, while making it a subtype of `AbstractSpace`.
1. Extend `random_position(model)`.
1. Extend `add_agent_to_space!(agent, model), remove_agent_from_space!(agent, model)`. This already provides access to `add_agent!, kill_agent!` and `move_agent!`.
1. Extend `nearby_ids(position, model, r)`.
1. Create a new "minimal" agent type to be used with [`@agent`](@ref) (see the source code of [`GraphAgent`](@ref) for an example).

And that's it! Every function of the main API will now work. In some situations you might want to explicitly extend other functions such as `move_agent!` for performance reasons.

### Visualization of a custom space
Visualization of a new space type within Agents.jl works in a very similar fashion to 
creating a new space type.
As before, all custom space types should implement this API and be subtypes of 
`AbstractSpace`.
To implement this API for your custom space:

1. Copy the methods from the list below.
    Make sure to also copy the first line defining the `ABMPlot` type in your working 
    environment which is necesary to be able to extend the API.
    Inside `ABMPlot` you can find all the plot args and kwargs as well as the plot 
    properties that have been lifted from them (see the "Lifting" section of this API).
    You can then easily access them inside your functions via the dot syntax, e.g. with
    `p.color` or `p.plotkwargs`, and use them as needed.
1. Replace `Agents.AbstractSpace` with the name of your space type.
1. Implement at least the required methods.
1. Implement optional methods as needed.
    Some methods DO NOT need to be implemented for every space, they are optional.
    The necessity to implement these methods depends on the supertypes of your custom type.
    For example, you will get a lot of methods "for free" if your `CustomType` is a subtype 
    of `Agents.AbstractGridSpace`.
    As a general rule of thumb: The more abstract your `CustomSpace`'s supertype is, the 
    more methods you will have to extend/adapt.

!!! info "Checking for missing methods"
    We provide a convenient function `Agents.check_space_visualization_API(::ABM)` to check 
    for the availability of methods used to plot ABMs with custom spaces via `abmplot`. 
    By default, the function is called whenever you want to plot a custom space. 
    This behavior can be disabled by passing `enable_space_checks = false` as a keyword 
    argument to `abmplot`.

The methods to be extended for visualization of a new space type are structured into four
groups:

```julia
## Required
const ABMPlot = Agents.get_ABMPlot_type()

function Agents.agents_space_dimensionality(space::Agents.AbstractSpace) 
end

function Agents.get_axis_limits(model::ABM{<:Agents.AbstractSpace})
end

function Agents.agentsplot!(ax, model::ABM{<:Agents.AbstractSpace}, p::ABMPlot)
end

## Preplots (optional)

function Agents.spaceplot!(ax, model::ABM{<:Agents.AbstractSpace}; spaceplotkwargs...)
end

function Agents.static_preplot!(ax, model::ABM{<:Agents.AbstractSpace}, p::ABMPlot)
end

## Lifting (optional)

function Agents.abmplot_heatobs(model::ABM{<:Agents.AbstractSpace}, heatarray)
end

function Agents.abmplot_pos(model::ABM{<:Agents.AbstractSpace}, offset)
end

function Agents.abmplot_colors(model::ABM{<:Agents.AbstractSpace}, ac)
end
function Agents.abmplot_colors(model::ABM{<:Agents.AbstractSpace}, ac::Function)
end

function Agents.abmplot_markers(model::ABM{<:Agents.AbstractSpace}, am, pos)
end
function Agents.abmplot_markers(model::ABM{<:Agents.AbstractSpace}, am::Function, pos)
end

function Agents.abmplot_markersizes(model::ABM{<:Agents.AbstractSpace}, as)
end
function Agents.abmplot_markersizes(model::ABM{<:Agents.AbstractSpace}, as::Function)
end

#### Inspection (optional)

function Agents.convert_mouse_position(::S, pos) where {S<:Agents.AbstractSpace}
end

function Agents.ids_to_inspect(model::ABM{<:Agents.AbstractSpace}, pos)
end
```

!!! tip "Changing visualization of existing space types" 
    The same approach outlined above also applies in cases when you want to overwrite the 
    default methods for an already existing space type.
    For instance, this might often be the case for models with `Nothing` space.

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
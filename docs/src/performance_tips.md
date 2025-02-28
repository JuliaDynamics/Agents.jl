# Performance Tips

Here we list various tips that will help users make faster ABMs with Agents.jl.
Please do read through Julia's own [Performance Tips](https://docs.julialang.org/en/v1/manual/performance-tips/#man-performance-tips) section as well, as it will help you write performant code in general.

## Benchmark your stepping functions!
By design Agents.jl allows users to create their own arbitrary stepping functions that control the time evolution of the model.
This provides maximum freedom on creating an ABM.
However, it has the downside that Agents.jl cannot help you with the performance of the stepping functions themselves.
So, be sure that you benchmark your code, and you follow Julia's Performance Tips!

## Take advantage of parallelization
In Agents.jl we offer native parallelization over the full model evolution and data collection loop. This is done by providing a `parallel = true` keyword argument to [`ensemblerun!`](@ref) or [`paramscan`](@ref). This uses distributed computing via Julia's `Distributed` module. For that, start Julia with `julia -p n` where `n` is the number of processing cores or add processes from within a Julia session using:

```julia
using Distributed
addprocs(4)
```

For distributed computing to work, all definitions must be preceded with
`@everywhere`, e.g.

```julia
using Distributed
@everywhere using Agents
@everywhere function initialized
@everywhere @agent struct SchellingAgent(...) ...
@everywhere function agent_step!(...) = ...
@everywhere adata = ...
```

To avoid having `@everywhere` in everywhere, you can use the
`@everywhere begin...end` block, e.g.
```julia
@everywhere begin
    using Agents
    using Random
    using Statistics: mean
    using DataFrames
end
```

To further reduce the use of `@everywhere` you can move the core
definition of your model in a file, e.g.
in `schelling.jl`:
```
using Agents
function initialize(...) ...
@agent struct SchellingAgent(...) ...
function agent_step!(...) = ...
```
then `include` the file with `everywhere`:
```
@everywhere include("schelling.jl")
```

## In-model parallelization

Julia provides several tools for [parallelization and distributed computing](https://docs.julialang.org/en/v1/manual/parallel-computing/).
Notice that we cannot help you with parallelizing the _actual model evolution_ via the agent- and model-stepping functions. This is something you must do manually, as depending on the model, parallelization might not be possible at all due to e.g. the access and overwrite of the same memory location (writing on same agent in different threads or killing/creating agents).
If your model evolution satisfies the [criteria allowing parallelism](https://docs.julialang.org/en/v1/manual/multi-threading/#Caveats), the simplest way to do it is using Julia's [`@threads` or `@spawn` macros](https://docs.julialang.org/en/v1/manual/multi-threading/#man-multithreading).


## Use Type-stable containers for the model properties
This tip is actually not related to Agents.jl and you will also read about it in Julia's [abstract container tips](https://docs.julialang.org/en/v1/manual/performance-tips/#man-performance-abstract-container). In general, avoid containers whose values are of unknown type. E.g.:

```julia
using Agents
@agent struct MyAgent(NoSpaceAgent) <: AbstractAgent
end
properties = Dict(:par1 => 1, :par2 => 1.0, :par3 => "Test")
model = StandardABM(MyAgent; properties = properties)
model_step!(model) = begin
	a = model.par1 * model.par2
end
```
is a bad idea, because of:
```julia
@code_warntype model_step!(model)
```

```julia
Variables
  #self#::Core.Compiler.Const(model_step!, false)
  model::AgentBasedModel{Nothing,MyAgent,typeof(fastest),Dict{Symbol,Any},Random.MersenneTwister}
  a::Any

Body::Any
1 ─ %1 = Base.getproperty(model, :par1)::Any
│   %2 = Base.getproperty(model, :par2)::Any
│   %3 = (%1 * %2)::Any
│        (a = %3)
└──      return %3
```
which makes the model stepping function have type instability due to the model properties themselves being type unstable.

The solution is to use a Dictionary for model properties only when all values are of the same type, or to use a custom `mutable struct` for model properties where each property is type annotated, e.g:
```julia
@kwdef mutable struct Parameters
	par1::Int = 1
	par2::Float64 = 1.0
	par3::String = "Test"
end

properties = Parameters()
model = StandardABM(MyAgent; properties = properties)
```

## Don't use agents to represent a spatial property
In some cases there is some property that exists in every point of a discrete space, e.g.
the amount of grass, or whether there is grass or not, or whether there is a tree there that is burning or not.
This most typically happens when one simulates a cellular automaton.

It might be tempting to represent this property as a specific type of agent like `Grass` or `Tree`, and add an instance of this agent in every position of the [`GridSpace`](@ref).
However, in Agents.jl this is not necessary and a much more performant approach can be followed.
Specifically, you can represent this property as a standard Julia `Array` that is a property of the model. This will typically lead to a 5-10 fold increase in performance.

For an example of how this is done, see the [Forest fire](https://juliadynamics.github.io/AgentsExampleZoo.jl/dev/examples/forest_fire/) model, which is a cellular automaton that has no agents in it, or the [Daisyworld](https://juliadynamics.github.io/AgentsExampleZoo.jl/dev/examples/daisyworld/) model, which has both agents as well as a spatial property represented by an `Array`.

## [Multiple agent types: `@multiagent` versus `Union` types](@id multi_vs_union)

Due to the way Julia's type system works, and the fact that agents are grouped in a container mapping IDs to agent instances, using a `Union` for different agent types always creates a performance hit because it leads to type instability.

The [`@multiagent`](@ref) macro enclose all types in a single one making working with it type stable.

In the following script, which you can find in `test/performance/variable_agent_types_simple_dynamics.jl`, we create a basic money-exchange ABM with many different agent types (up to 15), while having the simulation rules the same regardless of how many agent types are there.
We then compare the performance of the two versions for multiple agent types, incrementally employing more agents from 2 to 15.
Here are the results of how much time it took to run each version:

```@example performance
using Agents
x = pathof(Agents)
t = joinpath(dirname(dirname(x)), "test", "performance", "variable_agent_types_simple_dynamics.jl")
include(t)
```

Finally, we also have a more realistic benchmark of the two approaches at [`test/performance/multiagent_vs_union.jl`](https://github.com/JuliaDynamics/Agents.jl/blob/main/test/performance/multiagent_vs_union.jl) where each type has a different set of behaviours, unlike in the previous benchmark. The result of running the model with the two methodologies are

```@example performance_2
using Agents
x = pathof(Agents)
t = joinpath(dirname(dirname(x)), "test", "performance", "multiagent_vs_union.jl")
include(t)
```

As you can see, [`@multiagent`](@ref) has the edge over a `Union`: there is a general 1.5-2x advantage in many cases
in its favour. This is true for Julia>=1.11, where we then suggest to go with [`@multiagent`](@ref) only if the speed of the
simulation is critical. However, keep in mind that on Julia<=1.10 the difference is much bigger: [`@multiagent`](@ref)
is almost one order of magnitude faster than a `Union`.


# Performance Tips

Here we list various tips that will help users make faster ABMs with Agents.jl.
These will typically come at the cost of ease of use, or clarity and extend of source code.
Because otherwise, if they had no downsides, we would have already implemented them in Agents.jl.

Notice that most tips presented here are context-specific. This means if you truly care about performance of your model, because you intend to do massive simulations, it is probably worth it to test all approaches until you conclude which one is the most performant.

Please do read through Julia's own [Performance Tips](https://docs.julialang.org/en/v1/manual/performance-tips/#man-performance-tips) section as well, as it will help you write performant code in general.

## Use Type-stable containers for the model properties
This tip is actually not related to Agents.jl and you will also read about it in Julia's [abstract container tips](https://docs.julialang.org/en/v1/manual/performance-tips/#man-performance-abstract-container). In general, avoid containers whose values are of unknown type. E.g.:

```julia
using Agents
struct MyAgent <: AbstractAgent
	id::Int
end
properties = Dict(:par1 => 1, :par2 => 1.0, :par3 => "Test")
model = ABM(MyAgent; properties = properties)
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

The solution is to use a Dictionary for model properties only when all values are of the same type, or to use a custom `mutable struct` for model properties where each property is type annoted, e.g:
```julia
Base.@kwdef mutable struct Parameters
	par1::Int = 1
	par2::Float64 = 1.0
	par3::String = "Test"
end

properties = Parameters()
model = ABM(MyAgent; properties = properties)
```

## Avoid `Union`s of many different agent types (temporary!)
Due to the way Julia's type system works, and the fact that agents are grouped in a dictionary mapping IDs to agent instances, using multiple types for different agents always creates a performance hit because it leads to type instability.

Thankfully, due to some performance enhancements in Base Julia, unions of up to three different Agent types do not suffer much. You can see this by running the `test/performance/variable_agent_types_simple_dynamics.jl` file, which benchmarks the time to run a model that will do exactly the same amount of numeric operations, but each time subdividing it among an increasing number of agent types. Its output is

```@example performance
using Agents
x = pathof(Agents)
t = joinpath(dirname(dirname(x)), "test", "performance", "variable_agent_types_simple_dynamics.jl")
include(t)
```

**Notice that this is a temporary problem! In the future we plan to re-work Agents.jl internals regarding multi-agent models and deal with this performance hit without requiring the user to do something differently.**

At the moment, if you want to use many different agent types, you can try including all properties all types should have. You can specify what "type" of agent it is via including a field `type` or `kind` whose value is a symbol: `:wolf, :sheep, :grass`. Properties that should only belong to one kind of agent could be initialized with a "null" value for the other kinds. This will increase the amount of memory used by the model, as all agent instances will contain more data than necessary, so you need to check yourself if the performance gain due to type stability makes up for it.

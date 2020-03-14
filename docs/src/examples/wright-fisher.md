```@meta
EditURL = "<unknown>/../examples/wright-fisher.jl"
```

# Wright-Fisher model of evolution

This is one of the simplest models of population genetics that demonstrates the
use of [`sample!`](@ref).
We implement a simple case of the model where we study haploids (cells with a single set
of chromosomes) while for simplicity focusing only on one locus (a specific gene).
In this example we will be dealing with a population of constant size.

## A neutral model

* Imagine a population of `n` haploid individuals.
* At each generation, `n` offsprings replace the parents.
* Each offspring chooses a parent at random and inherits its genetic material.

```@example wright-fisher
using Agents
n = 100
```

Let's define an agent. The genetic value of an agent is a number (`trait` field).

```@example wright-fisher
mutable struct Haploid <: AbstractAgent
    id::Int
    trait::Float64
end
```

And make a model without any spatial structure:

```@example wright-fisher
m = ABM(Haploid)
```

Create `n` random individuals:

```@example wright-fisher
for i in 1:n
    add_agent!(m, rand())
end
```

To create a new generation, we can use the `sample!` function. It chooses
random individuals with replacement from the current individuals and updates
the model. For example:

```@example wright-fisher
sample!(m, nagents(m))
```

The model can be run for many generations and we can collect the average trait
value of the population. To do this we will use a model-step function (see [`step!`](@ref))
that utilizes [`sample!`](@ref):

```@example wright-fisher
modelstep_neutral!(m) = sample!(m, nagents(m))
```

We can now run the model and collect data. We use `dummystep` for the agent-step
function (as the agents perform no actions).

```@example wright-fisher
using Statistics: mean

data = step!(m, dummystep, modelstep_neutral!, 20, Dict(:trait => [mean]))
```

As expected, the average value of the "trait" remains around 0.5.

## A model with selection

We can sample individuals according to their trait values, supposing that their
fitness is correlated with their trait values.

```@example wright-fisher
m = ABM(Haploid)
for i in 1:100
    add_agent!(m, rand())
end

modelstep_selection!(m::ABM) = sample!(m, nagents(m), :trait)

data = step!(m, dummystep, modelstep_selection!, 20, Dict(:trait => [mean]))
```

Here we see that as time progresses the trait comes closer and closer to 1,
which is expected as agents with higher traits have higher probability of being
sampled for the next "generation".


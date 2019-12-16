# # Wright-Fisher model of evolution

# This is one of the simplest models of population genetics.
# We implement a simple case of the model with a single locus in a haploid 
# population of constant size.

# ## A neutral model

# * Imagine a population of 100 haploid individuals.
# * At each generation, 100 offsprings replace the parents.
# * Each offspring chooses a parent at random and inherits its genetic material.


using Agents

# Let's define an agent. The genetic value of an agent is a number (`trait` field).
mutable struct Agent <: AbstractAgent
    id::Int
    trait::Float64
end

m = ABM(Agent)

# Start 100 random individuals.
for i in 1:100
    add_agent!(m, rand()/rand())
end

# To create a new generation, we can use the `sample!` function. It chooses 100
# random individuals with replacement from the current individuals and updates
# the model.
sample!(m, nagents(m))

# The model can be run for many generations and we can collect the average trait
# value of the population.

# First, put the `sample!` in a step function that accepts a single argument:
# model object `m`.

modelstep_neutral!(m::ABM) = sample!(m, nagents(m))

# We can now run the model and collect data:
using StatsBase: mean

data = step!(m, dummystep, modelstep_neutral!, 20, Dict(:trait => [mean]))

# ## A model with selection

# We can sample individuals according to their trait values, supposing that their
# fitness is correlated with their trait values.

m = ABM(Agent)
for i in 1:100
    add_agent!(m, rand()/rand())
end

modelstep_selection!(m::ABM) = sample!(m, nagents(m), :trait)

data = step!(m, dummystep, modelstep_selection!, 20, Dict(:trait => [mean]))

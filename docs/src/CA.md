### Cellular automata

Building cellular automata (CA) with `Agents.jl` is straightforward. Since CA have been studied extensively,  `Agents.jl` provides modules for building and visualizing one- and two-dimensional CA. The following is an example of building Wolfram's rule 22.

```julia
using Agents
using Agents.CA1D
# Define the rule
rules = Dict("111"=>"0", "110"=>"0", "101"=>"0", "100"=>"1", "011"=>"0", "010"=>"1", "001"=>"1", "000"=>"0")  # rule 22

# Build the model
model = CA1D.build_model(rules=rules, ncols=101)  # creates a model where all columns are "0"
# change one cell's status:
model.agents[50].status="1"

# Run the model, collect data, and visualize it 
runs = 100
CA1D.ca_run(model, runs)
```

And the following is an example of 2D CA implementing Conway's game of life:

```julia
using Agents
using Agents.CA2D

# Define the rule
rules = (2,3,3)

# Build the model
model = CA2D.build_model(rules=rules, 
 dims=(100, 100), Moore=true)
# make some random cells alive
for i in 1:nv(model.space.dimensions)
 if rand() < 0.05
  model.agents[i].status="1"
 end
end

# Run the model, collect data, and visualize them 
runs = 50
CA2D.ca_run(model, runs)
```

Rules of a 2D cellular automaton in the `CA2D` module follow DSR (Death, Survival, Reproduction). Cells die if the number of their living neighbors are <D, survive if the number of their living neighbors are <=S, come to life if their living neighbors are as many as R.
# # Two-dimensional cellular automata 
# Agents.jl provides a module (CA2D) to create and plot 2D cellular automata.

using Agents
using Agents.CA2D
using AgentsPlots

# ## 1. Define the rule
# Rules of Conway's game of life: DSR (Death, Survival, Reproduction). 
# Cells die if the number of their living neighbors are <D, 
# survive if the number of their living neighbors are <=S,
# come to life if their living neighbors are as many as R.
rules = (2,3,3)

# ## 2. Build the model
# "CA2D.build_model" creates a model where all cells are by default off ("0")
model = CA2D.build_model(rules=rules, dims=(100, 100), Moore=true)

# Let's make some random cells on
for i in 1:nv(model)
  if rand() < 0.1
    model.agents[i].status="1"
  end
end

# ## 3. Run the model and collect data
runs = 10
data = CA2D.ca_run(model, runs);

# ## 4. Visualize the data
# This creates one figure for each step of the simulation
plot_CA2D(data, savename="gameOfLife", nodesize=2)
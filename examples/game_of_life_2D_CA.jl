using Agents.CA2D
using AgentsPlots

# Agents.jl provides a module to create and plot 2D cellular automata.

# Define the rule
# Rules of Conway's game of life: DSR (Death, Survival, Reproduction). 
# Cells die if the number of their living neighbors are <D, 
# survive if the number of their living neighbors are <=S,
# come to life if their living neighbors are as many as R.
rules = (2,3,3)

# 1. Build the model
# "CA2D.build_model" creates a model where all cells are "0"
model = CA2D.build_model(rules=rules, dims=(100, 100), Moore=true)
# make some random cells alive
for i in 1:nv(model)
  if rand() < 0.1
    model.agents[i].status="1"
  end
end

# 2. Run the model, collect data, and visualize it 
runs = 10
data = CA2D.ca_run(model, runs);

# 3. Visualize the data
# This creates one figure for each step of the simulation
plot_CA2D(data, savename="gameOfLife", nodesize=2)
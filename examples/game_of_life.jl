using Agents
using Agents.CA2D

# 0. Define the rule
# Rules of Conway's game of life: DSR (Death, Survival, Reproduction). Cells with living neighbors < D, die. Cell with living agents <= S, survives. Cell with living neighbors = R, come to life.
rules = (2,3,3)

# 1. Build the model
model = CA2D.build_model(rules=rules, dims=(100, 100), Moore=true)  # creates a model where all cells are "0"
# make some random cells alive
for i in 1:gridsize(model.space.dimensions)
  if rand() < 0.1
    model.agents[i].status="1"
  end
end

# 2. Run the model, collect data, and visualize it 
runs = 50
CA2D.ca_run(model, runs)

# convert -delay 10 -loop 1 *.png animation.gif
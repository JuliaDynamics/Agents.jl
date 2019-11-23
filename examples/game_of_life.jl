using Agents
using Agents.CA2D

# 0. Define the rule
# Rules of Conway's game of life: DSR (Death, Survival, Reproduction). Cells die if the number of their living neighbors are $<D$, survive if the number of their living neighbors are $<=S$, come to life if their living neighbors are as many as $R$.
rules = (2,3,3)

# 1. Build the model
model = CA2D.build_model(rules=rules, dims=(100, 100), Moore=true)  # creates a model where all cells are "0"
# make some random cells alive
for i in 1:nv(model)
  if rand() < 0.1
    model.agents[i].status="1"
  end
end

# 2. Run the model, collect data, and visualize it 
runs = 50
data = CA2D.ca_run(model, runs);


# 3. Visualize the data
using AgentsPlots
visualize_2DCA(data, model, :pos, :status, runs, savename="gameOfLife")

# Animate the figures:
# convert -delay 10 -loop 1 *.png animation.gif
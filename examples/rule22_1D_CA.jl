# # One-dimensional cellular automata 
# Agents.jl provides a module (CA1D) to create and plot 1D cellular automata.

using Agents
using Agents.CA1D
using AgentsPlots

# ## 1. Define the rule
# Here is Wolfram's rule 22

rules = Dict("111"=>"0", "110"=>"0", "101"=>"0", "100"=>"1", "011"=>"0",
            "010"=>"1", "001"=>"1", "000"=>"0")

# ## 2. Build the model
# All the cells are by default initially "off" 
model = CA1D.build_model(rules=rules, ncols=101)

# This turns on the middle cell
model.agents[51].status="1"

# ## 3. Run the model and collect data.
runs = 100
data = CA1D.ca_run(model, runs);

# ## 4. Visualize the data
plot_CA1D(data, savename="rule22", nodesize=2)

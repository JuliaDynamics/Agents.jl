using Agents.CA1D
using AgentsPlots

# Agents.jl provides a module to create and plot 1D cellular automata.

# 0. Define the rule
# Wolfram's rule 22
rules = Dict("111"=>"0", "110"=>"0", "101"=>"0", "100"=>"1", "011"=>"0",
            "010"=>"1", "001"=>"1", "000"=>"0")

# 1. Build the model
model = CA1D.build_model(rules=rules, ncols=101)
# turn on the middle cell
model.agents[51].status="1"

# 2. Run the model and collect data.
runs = 100
data = CA1D.ca_run(model, runs);

# 3. Visualize the data
plot_CA1D(data, savename="rule22", nodesize=2)

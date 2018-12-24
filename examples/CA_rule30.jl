using Agents
using Agents.CA1D

# 0. Define the rule
# rules = Dict("111"=>"0", "110"=>"0", "101"=>"0", "100"=>"1", "011"=>"1", "010"=>"1", "001"=>"1", "000"=>"0")  # rule 30
rules = Dict("111"=>"0", "110"=>"0", "101"=>"0", "100"=>"1", "011"=>"0", "010"=>"1", "001"=>"1", "000"=>"0")  # rule 22

# 1. Build the model
model = CA1D.build_model(rules=rules, ncols=101)  # creates a model where all columns are "0"
model.agents[50].status="1"

# 2. Run the model, collect data, and visualize it 
runs = 100
CA1D.ca_run(model, runs)
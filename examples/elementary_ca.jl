# Implementation of an elementary cellular automata
# according to https://mathworld.wolfram.com/ElementaryCellularAutomaton.html
# uses random initialization and uses wolfram codes to specify the rule
# synchronous update of the 1D lattice

using Agents, Random
using CairoMakie
using InteractiveDynamics
using CSV

"""
The automaton living in a 1D space
"""
mutable struct Cell <: AbstractAgent
    id::Int
    pos::Dims{1}
    status::Int # either 0 or 1, where 1 is 'alive'
end

"""
Returns an array with the rule for the next status configurations, 1-indexed.

Thus, the first position corresponds to the rule for the cell neighborhood status (0,0,0) 
and the last to (1,1,1)
"""
function rule_from_code(wolfram_code)
    return digits(wolfram_code, base=2, pad=8)
end

"""
Takes the status of a neighborhood and returns the corresponding 
index in the model rule (0,0,0) -> 1 (0,1,0) -> 3
"""
function configuration_index(cell_statuses)
    # takes the tuples and forms a string (0,1,1) -> "011"
    binary_code = string(cell_statuses...)
    # turns the string binary code into the integer
    index = parse(Int, binary_code, base=2) + 1
    return index
end

"""
Given a cell checks its neighbors and 
decides the next status of the cell based on the model rule
"""
function next_status(cell, model)
    neighbors = collect(nearby_agents(cell, model))
    cell_statuses = (c.status for c in [neighbors[1], cell, neighbors[2]])
    index = configuration_index(cell_statuses)
    return model.rule[index]
end

"""
Initializes the ABM

# Arguments
- `n_cells::Int`: total of cell automaton
- `wolfram_code::Int`: wolfram code for the rule
- `seed::Int`: random seed
"""
function build_model(; n_cells = 100, wolfram_code=30, seed = 30)
    space = GridSpace((n_cells,); metric=:chebyshev)

    properties = Dict(:rule => rule_from_code(wolfram_code),)
    model = ABM(
        Cell, 
        space; properties,
        rng = MersenneTwister(seed))

    for x in 1:n_cells
        cell = Cell(nextid(model), (x,), rand([0,1]))
        add_agent_pos!(cell, model)
    end

    return model
end

"""
Dummy update of the cells
"""
function cell_step!(_, _)

end

"""
Performs a synchronous update of all cells
"""
function ca_step!(model)
    new_statuses = fill(0, nagents(model))
    for agent in allagents(model)
        new_statuses[agent.id] = next_status(agent, model)
    end

    for id in allids(model)
        model[id].status = new_statuses[id]
    end
end

# Initialize model
model = build_model(n_cells=100)

# Runs the model and collects data
data, _ = run!(model, cell_step!, ca_step!, 100; adata=[:status]);

# The data contains the step, id/position and status of the cell (1/0)
data

CSV.write("ca_data.csv", data);

# Lets plot the time evolution in the y axis
heatmap(data.id, data.step, data.status, colormap=:Blues_3)
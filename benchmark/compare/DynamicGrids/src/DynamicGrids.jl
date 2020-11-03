using DynamicGrids
using BenchmarkTools

function initialise(; density = 0.7)
    DEAD, ALIVE, BURNING = 1, 2, 3

    forest = let
        Neighbors(VonNeumann(1)) do neighborhood, cell
            if cell == ALIVE
                if BURNING in neighborhood
                    BURNING
                else
                    cell
                end
            elseif cell == BURNING
                DEAD
            else
                cell
            end
        end
    end
    # Set up the init array and output
    init = fill(DEAD, 100, 100)
    for position in CartesianIndices(init)
        if rand() < density
            state = position[2] == 1 ? BURNING : ALIVE
            init[position] = state
        end
    end

    return init, forest
end

function run_forest(init, forest)
    output = ArrayOutput(init; tspan = 1:100)

    # Run the simulation
    sim!(output, forest)
end

a = @benchmark run_forest(init, forest) setup = ((init, forest) = initialise())
println("DynamicGrids.jl ForestFire (ms): ", minimum(a.times) * 1e-6)

